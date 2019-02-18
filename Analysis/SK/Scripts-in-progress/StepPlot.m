% StepPlot.m

%% Import and divide by genotype

%use filtCells instead of allCells to run ExcludeSweeps
% rsFiltCells = ephysRecordingBase([ephysRecordingBase{2:89,20}]'==1,2)
% filtCells = allCells(ismember(allCells,rsFiltCells))

protList = {'WC_Probe','WC_ProbeSmall','WC_ProbeLarge'};
matchType = 'full';
ExcludeSweeps(ephysData, allCells, 1, protList, matchType);

stepTracePicks = ImportMetaData(); % AllWCStepsTo104TracePicks.xls
stepTracePicks = metaDataConvert(stepTracePicks);
ephysRecordingBase = ImportMetaData(); % RecordingDatabase.xls
stepCells = unique(stepTracePicks(:,1));

genotype = cell(length(allCells),2);
for i=1:length(allCells)
    genotype(i,1) = allCells(i);
    genotype(i,2) = ephysRecordingBase(strcmp(ephysRecordingBase(:,2),allCells(i)),3);    
end

wtCells = allCells(strcmp(genotype(:,2),'TU2769'));
fatCells = allCells(strcmp(genotype(:,2),'GN381'));
wtStepCells = stepCells(ismember(stepCells,wtCells));
fatStepCells = stepCells(ismember(stepCells,fatCells));

%% Run IDAnalysis and filter empty results
mechPeaksWT = IdAnalysis(ephysData,wtStepCells,0);
mechPeaksFat = IdAnalysis(ephysData,fatStepCells,0);

mechCellsWT = allCells(~cellfun('isempty',mechPeaksWT(:,1)));
mechPeaksWT = mechPeaksWT(~cellfun('isempty',mechPeaksWT(:,1)),:);
mechCellsFat = allCells(~cellfun('isempty',mechPeaksFat(:,1)));
mechPeaksFat = mechPeaksFat(~cellfun('isempty',mechPeaksFat(:,1)),:);

%% Sort peaks and get means by step size across recordings

%TODO: Modify IDAnalysis to get PDStepSizes with mean/SD for horiz errbars

sTest = mechPeaksWT;
% sTest = mechPeaksFat;

sCat = vertcat(sTest{:,1});
sCat(sCat==6.9)=7;
sCat(sCat==8.9)=9;
sCat(sCat==10.9)=11;
[~,sizeSortIdx] = sort(sCat(:,1));
sSort = sCat(sizeSortIdx,:);

[eachSize,sizeStartIdx,~] = unique(sSort(:,1),'first');
[~,sizeEndIdx,~] = unique(sSort(:,1),'last');
nSizes = sum(~isnan(eachSize));

for iSize = 1:nSizes
sizeIdx = sizeStartIdx(iSize):sizeEndIdx(iSize);
sizeCount = sizeEndIdx(iSize)-sizeStartIdx(iSize)+1;
meansBySize(iSize,1) = nanmean(sSort(sizeIdx,3));
stdBySize(iSize,1) = nanstd(sSort(sizeIdx,3));
stErrBySize(iSize,1) = stdBySize(iSize)/sqrt(sizeCount);
end

sSortWT = sSort;

stepMeansWT = [eachSize meansBySize stErrBySize];
% stepMeansFat = [eachSize meansBySize stErrBySize];

% errorbar(eachSize,meansBySize,stErrBySize)
% errorbar(eachSize,meansBySize,stErrBySize,'r')

clear sCat  sizeSortIdx sizeStartIdx sizeEndIdx iSize nSizes sizeIdx 
clear meansBySize stdBySize stErrBySize

%% Get recording names for sorted peaks

sTest = mechPeaksWT;

sCat = vertcat(sTest{:,1}); 
[~,sizeSortIdx] = sort(sCat(:,1));
sSort = sCat(sizeSortIdx,:);

sCatTrace = vertcat(sTest{:,2});
sCatName = vertcat(sTest{:,4});
sSortTrace = sCatTrace(sizeSortIdx,:);
sSortName = sCatName(sizeSortIdx,:);

sSortTraceWT = sSortTrace;
sSortNameWT = sSortName;

%% Save mechPeaks in format for Igor's I-dCellFits

peaky = mechPeaksWT;

% StepSize FAT1on FAT2on
nCells = size(peaky,1);
onToIgor = nan(length(eachSize),nCells+1);
onToIgor(:,1) = eachSize;
offToIgor = nan(length(eachSize),nCells+1);
offToIgor(:,1) = eachSize;
colNames = cell(1,nCells+1);
colNames(1) = {'StepSize'};

for i = 1:nCells
    peakyTable = peaky{i,1};
    nSizes = size(peakyTable,1);
    for j = 1:nSizes
        onToIgor(eachSize==peakyTable(j,1),i+1)=peakyTable(j,3);
        offToIgor(eachSize==peakyTable(j,1),i+1)=peakyTable(j,4);
    end
    
    colNames {i+1} = peaky{i,4}(1,:);
end

wtOnToIgor = onToIgor;
wtOffToIgor = offToIgor;
wtColsToIgor = colNames;

%% Save toIgors as delimited text

% copy headers into Excel and save each as csv
% wtColsToIgor(2:end) = cellfun(@(x) horzcat(x,' on'), wtColsToIgor(2:end),'UniformOutput',0);
% wtColsToIgor(2:end) = cellfun(@(x) strrep(x,'on','off'), wtColsToIgor(2:end),'UniformOutput',0);
% fatColsToIgor(2:end) = cellfun(@(x) horzcat(x,' on'), fatColsToIgor(2:end),'UniformOutput',0);
% fatColsToIgor(2:end) = cellfun(@(x) strrep(x,'on','off'), fatColsToIgor(2:end),'UniformOutput',0);

% then for each, append data
dlmwrite('PatchData/IgorFatOffs.csv',fatOffToIgor,'-append')

%% Normalize from igor sigmoid fits
% cols = WtOnMax, WtOnXHalf, WtOnRate, WtOffMax, WtOffXHalf, WtOffRate

for i = 1:size(wtStats,1)
    wtOnNorm(:,i) = wtOnToIgor(:,i+1)/wtStats(i,1);
end

for i = 1:size(wtStats,1)
    wtOffNorm(:,i) = wtOffToIgor(:,i+1)/wtStats(i,4);
end

for i = 1:size(fatStats,1)
    fatOnNorm(:,i) = fatOnToIgor(:,i+1)/fatStats(i,1);
end

for i = 1:size(fatStats,1)
    fatOffNorm(:,i) = fatOffToIgor(:,i+1)/fatStats(i,4);
end
% 
% wtColsToIgor(2:end) = cellfun(@(x) horzcat(x,' on'), wtColsToIgor(2:end),'UniformOutput',0);
% wtColsToIgor(2:end) = cellfun(@(x) strrep(x,'on','off'), wtColsToIgor(2:end),'UniformOutput',0);
% fatColsToIgor(2:end) = cellfun(@(x) horzcat(x,' on'), fatColsToIgor(2:end),'UniformOutput',0);
% fatColsToIgor(2:end) = cellfun(@(x) strrep(x,'on','off'), fatColsToIgor(2:end),'UniformOutput',0);

dlmwrite('PatchData/IgorWtOnNorms.csv',wtOnNorm,'-append')
dlmwrite('PatchData/IgorWtOffNorms.csv',wtOffNorm,'-append')
dlmwrite('PatchData/IgorFatOnNorms.csv',fatOnNorm,'-append')
dlmwrite('PatchData/IgorFatOffNorms.csv',fatOffNorm,'-append')

%% Traces for tau fitting to Igor

dlmwrite('PatchData/IgorWtStepTraces.csv',sSortTraceWT')
dlmwrite('PatchData/IgorFatStepTraces.csv',sSortTraceFat')


%% Traces copied in next to sSort rates column
sSort = sSortIgorTausWT;
% sSort = sSortIgorTausFat;

[eachSize,sizeStartIdx,~] = unique(sSort(:,1),'first');
[~,sizeEndIdx,~] = unique(sSort(:,1),'last');
nSizes = sum(~isnan(eachSize));

for iSize = 1:nSizes
sizeIdx = sizeStartIdx(iSize):sizeEndIdx(iSize);
sizeCount = sizeEndIdx(iSize)-sizeStartIdx(iSize)+1;

tau1BySize(iSize,1) = nanmean(sSort(sizeIdx,2));
tau1StdBySize(iSize,1) = nanstd(sSort(sizeIdx,2));
tau1StErrBySize(iSize,1) = tau1StdBySize(iSize)/sqrt(sizeCount);

tau2BySize(iSize,1) = nanmean(sSort(sizeIdx,3));
tau2StdBySize(iSize,1) = nanstd(sSort(sizeIdx,3));
tau2StErrBySize(iSize,1) = tau2StdBySize(iSize)/sqrt(sizeCount);
end

tausBySizeWT = [tau1BySize tau1StdBySize tau1StErrBySize tau2BySize tau2StdBySize tau2StErrBySize];
% tausBySizeFat = [tau1BySize; tau1StdBySize; tau1StErrBySize; tau2BySize; tau2StdBySize; tau2StErrBySize];

errorbar(eachSize,tau2BySize,tau1StErrBySize)
% errorbar(eachSize,tau2BySize,tau1StErrBySize,'r')

