% findMRCs_old.m
%
% TODO: Make it so stimStart can be a vector, to find multiple peaks in a
% given trace (both pn and off currents, multiple on currents, etc.)

function [pk, pkLoc, pkThresh, varargout] = findMRCs_old(stimStart, traceData, sf, dataType)

smoothWindow = sf; % n timepoints for moving average window for findPeaks, as factor of sampling freq (kHz)
threshTime = 100; % use first n ms of trace for setting noise threshold

% Number of timepoints to skip after stimulus onset to avoid the stimulus
% artifact in peak-finding (dependent on sampling frequency in kHz).
switch sf
    case 5
        artifactOffset = sf*2; 
    case 10
        artifactOffset = sf*1.2; 
    otherwise
        artifactOffset = sf; % in case of non-standard sf, play safe by not cutting off too many points
end

% Smooth data with a moving average for peak finding and flip if current
% trace but not if voltage trace (for peak finding)
% TODO: Add a flag to make this usable in reversal potential peak finding,
% or use absolute value.
switch dataType
    case 'A'
        smooMean = -smooth(traceData',smoothWindow,'moving');
    case 'V'
        smooMean = smooth(traceData',smoothWindow,'moving');
end

% Set threshold based on noise of the first 100ms of the trace
% (i.e., size of signal needed to be seen above that noise)
pkThresh = 1.5*thselect(smooMean(1:threshTime*sf),'rigrsure');


% Find MRC peaks if they exist, otherwise set peak amplitude as 0.
% Calculate decay constant tau based on single exponent fit.

% sf*2.4 factor helps avoid stimulus artifact in peak finding
% for sf = 5kHz, skips first 12 timepoints after stim.
% NEXT: Redo this look with a cell where stim was 2.5kHz filtered and use
% that buffer instead, bc more cells have it. Or set timepoints based on
% stim filter freqz
[peaks, peakLocs] = findpeaks(smooMean(stimStart+artifactOffset:stimStart+(sf*1000/50)),...
    'minpeakheight',pkThresh);
if ~isempty(peaks)
    
    switch dataType
        case 'A'
            pk = max(peaks)*1E12; %pA
        case 'V'
            pk = max(peaks)*1E3; %mV
    end
    
    %TODO: Use grpdelay to adjust for filter delay? If there is one, this
    %might also help make the tau calculation more correct.
    peakLocs = peakLocs(peaks==max(peaks));
    pkLoc = peakLocs(1) + stimStart+artifactOffset; %account for start position
    
    % Find time for current to decay to 2/e of the peak or 75ms
    % after the peak, whichever comes first. Use that for fitting
    % the single exponential. Fit the unsmoothed mean trace.
    
    [~,fitInd] = min(abs(traceData(pkLoc:75*sf+pkLoc)...
        - (traceData(pkLoc)/(2*exp(1)))));
    
    fitTime = fitInd/sf; % seconds
    tVec = 0:1/sf:fitTime;
    
    pkFit = fit(tVec',traceData(pkLoc:pkLoc+fitInd)','exp1');
    tau = -1/pkFit.b;
    
    
else
    pk = 0;
    pkLoc = nan;
    
    tau = nan;
    pkFit = 0;
end

varargout{1} = tau;
varargout{2} = pkFit;

end