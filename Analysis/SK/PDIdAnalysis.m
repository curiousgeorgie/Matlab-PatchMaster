% PDIdAnalysis.m
% 
% This function calculates the mean peak current for each step size across
% a given recording, for making an I-d or I-x curve. Step size is
% calculated using findSteps with the stimulus command signal. 
% 
% Unlike IdAnalysis, this requires the photodiode signal to be included as
% channel 3 of the data.
% 
% USAGE:
%   mechPeaks = PDIdAnalysis(ephysData, allCells)
%
% INPUTS:
%   ephysData       struct          Imported data from ImportPatchData.
% 
%   allCells        cell array      List of recording names to analyze. 
% 
% PROMPTED INPUTS:
%   ImportMetaData asks for a metadata file in .xls format containing the
%   list of traces to analyze in the same format as files output by
%   ExcludeSweeps(). This will get double-checked against allCells.
% 
% OUTPUTS:
%   mechPeaks       cell array      Nested cell array with a cell for each
%                                   recording. Columns per recording:
%                                   [step size (um); peak current at step
%                                   onset (pA); peak current at offset; 
%                                   onset tau (ms); offset tau; onset
%                                   location (sample); offset location]
%   
% 
% Created by Sammy Katta on 20-May-2015.

% TODO: Add flag for using stim com signal vs. PD signal (chan 2 vs chan 3) 
% TODO: Pull stimCom 0.408 factor out as defined variable

function mechPeaks = PDIdAnalysis(ephysData, allCells)

% keyboard;

mechPeaks = cell(length(allCells),1);
stepThresh = 0.05; % step detection threshold in um, could be smaller
baseTime = 30; % length of time (ms) to use as immediate pre-stimulus baseline
smoothWindow = 5; % n timepoints for moving average window for findPeaks

% Load and format Excel file with lists (col1 = cell name, col2 = series number,
% col 3 = comma separated list of good traces for analysis)
mechTracePicks = ImportMetaData();
mechTracePicks = metaDataConvert(mechTracePicks);

% Find applicable series and check against list of included series/traces
% (this allows a cross-check on the protocol name) before analyzing
% Values for traces not on the list will be stored as NaN.
for iCell = 1:length(allCells)   
        
    allSizes = [];
    allLeakSub = [];
    allStarts = [];
    allEnds = [];
    
    % Given list of all cells, check which are on the approved list and use
    % those for analysis. Conversely, make sure the cells on the list match
    % the expected protocol type.
    cellName = allCells{iCell};
    allSeries = matchProts(ephysData,cellName,...
        {'WC_Probe','Probe_CC'},'MatchType','full');
    nSeries = length(allSeries);
    pickedSeries = mechTracePicks(find(strcmp(cellName,mechTracePicks(:,1))),[2,3]);
       
    for iSeries = 1:nSeries
        thisSeries = allSeries(iSeries);
        
        % Carry out analysis if this series is on the list
        try pickedTraces = pickedSeries{[pickedSeries{:,1}]==thisSeries,2};
        catch
            continue % if it's not on the list, go on to next series in for loop
        end
        
        probeI = ephysData.(cellName).data{1,thisSeries};
        % convert command V to um, at 0.408 V/um
        photodiodeV = ephysData.(cellName).data{3,thisSeries};
        % sampling frequency in kHz
        sf = ephysData.(cellName).samplingFreq{thisSeries} ./ 1000; 
        dataType = ephysData.(cellName).dataunit{1,thisSeries};
        nSteps = size(photodiodeV,2);
        
        [stepSize, stepStarts, stepEnds] = ...
            findSteps(nSteps, photodiodeV, sf, stepThresh);

        leakSubtract = ...
            SubtractLeak(probeI, sf, 'BaseLength', baseTime);

        % Concatenate to the complete list of step sizes and
        % leak-subtracted traces across series for this recording
        allSizes = [allSizes; stepSize];
        allStarts = [allStarts; stepStarts];
        allEnds = [allEnds; stepEnds];
        allLeakSub = [allLeakSub; leakSubtract'];
        
    end
       
    % Sort by size and take start/end indices of the data for each size
    [sortedSizes, sortIdx] = sort(allSizes);
    [eachSize,sizeStartIdx,~] = unique(sortedSizes,'first');
    [~,sizeEndIdx,~] = unique(sortedSizes,'last');
    nSizes = sum(~isnan(eachSize));
    
    sortedStarts = allStarts(sortIdx);
    sortedEnds = allEnds(sortIdx);
    sortedLeakSub = allLeakSub(sortIdx,:);
    
    % TODO: Store nReps as endIdx-StartIdx for each step size
    
    % Use start index for the start and end times, assuming they don't
    % change within a given step size (or whatever grouping you are using;
    % should work with different step lengths/intervals as well).
    startsBySize = sortedStarts(sizeStartIdx);
    endsBySize = sortedEnds(sizeStartIdx);
    
    meansBySize = NaN(nSizes,length(sortedLeakSub));
    pkThresh = zeros(nSizes,1);
    pkOn = zeros(nSizes,1);
    pkOff = zeros(nSizes,1);
    pkOnLoc = NaN(nSizes,1);
    pkOffLoc = NaN(nSizes,1);
    onsetTau = NaN(nSizes,1);
    offsetTau = NaN(nSizes,1);
    
    % Use start and end indices for each step size to take the mean of the
    % leak-subtracted trace corresponding to that step size. Then smooth
    % and find peaks near the step times.
    for iSize = 1:nSizes
        if sizeEndIdx(iSize)-sizeStartIdx(iSize)>0
            meansBySize(iSize,:) = mean(sortedLeakSub(sizeStartIdx(iSize):sizeEndIdx(iSize),:));
        else
            meansBySize(iSize,:) = sortedLeakSub(sizeStartIdx(iSize):sizeEndIdx(iSize),:);
        end
                
           
        % Find MRC peaks if they exist at the onset of the step, otherwise
        % set peak amplitude as NaN. Calculate decay constant tau based on
        % single exponent fit for onset and offset currents.

        [pkOn(iSize), pkOnLoc(iSize), pkThresh(iSize), onsetTau(iSize), ~] = ...
            findMRCs(startsBySize(iSize), meansBySize(iSize,:),sf, dataType);
        
        % Find MRC peaks at the offset of the step
        
        [pkOff(iSize), pkOffLoc(iSize), pkThresh(iSize), offsetTau(iSize), ~] = ...
            findMRCs(endsBySize(iSize), meansBySize(iSize,:),sf, dataType);
        
        
    end
    
    
    mechPeaks{iCell} = [eachSize(~isnan(eachSize)) pkOn pkOff onsetTau offsetTau pkOnLoc pkOffLoc];
    
    % TODO: Figure out how to fit this to the four-parameter sigmoidal
    % function used in O'Hagan: @(X,a,b,c,d) ((a-d)/(1+((X/c)^b)))+d
    % Using optimtool? fmincon? nlinfit if you add the statistics toolbox.
    
   
end

end