% AnalyzePatchData.m
% 
% TODO: Figure out import for RecordingDatabase.xlsx, add columns for OC,WC
% series numbers of interest and pull those.
% TODO: Pass in series numbers from spreadsheet for analysis, rather than
% analyzing all series with that protocol name (but check protocol name of
% those series and pass error if not).

%% Import Data
%this is a test

% Don't forget to run sigTOOL first!
% [ephysData,tree] = ImportPatchData();
% ephysData = ImportPatchData();
ephysData = ImportPatchData(ephysData);


% Keep only data with given project prefixes/names.
projects = {'FAT'};

ephysData = FilterProjectData(ephysData, projects);

clear projects
%% Analyze capacity transient for C, Rs, and tau

ephysData = CtAnalysis(ephysData);

%% Print list of Rs

recs = fieldnames(ephysData);

for i=1:length(recs)
fprintf('%s: %s\n', recs{i}, sprintf('%6g',round(ephysData.(recs{i}).Rs)))
end

%% Import metadata with info about which IVq protocols to look at

ephysMetaData = ImportMetaData();

%% Assign numbers of IVq series to look at

% Define anonymous function to convert cells from metadata to double arrays
% for protStart and protRs
CellToArray = @(x) reshape([x{:}],size(x,1),size(x,2), size(x,3));

% List which sets of ct_ivqs to use for on cell (col 2)/whole cell (col 3)
% calculations for the above selection of cells. (i.e., if the second  
% ct_ivq protocol run for that recording was the one you want to use for  
% whole-cell, put "2" in col 2 for that recording). Make sure it has three 
% sequential ivq pgfs.
allCells = ephysMetaData(2:end,1);

%TODO: don't assume headers: try/catch it
protStart = ephysMetaData(2:end,2:3)'; 
protStart = CellToArray(protStart);

protRs = ephysMetaData(2:end,4)';
protRs = CellToArray(protRs);


for i = 1:length(allCells)
    ephysData.(allCells{i}).protOC = protStart(1,i);
    ephysData.(allCells{i}).protWC = protStart(2,i);    
    ephysData.(allCells{i}).protRs = protRs(i);
end
clear i protStart protRs CellToArray
%% Process voltage steps

% allCells = {'FAT020';'FAT021';'FAT022';'FAT025';'FAT027';'FAT028';'FAT029';'FAT030';'FAT031';'FAT032'};
% 
% allIVs = IVAnalysis(ephysData,allCells);

% wtCells = {'FAT020';'FAT021';'FAT022';'FAT025';'FAT031';'FAT033';'FAT034';'FAT035'};
% fatCells = {'FAT027';'FAT028';'FAT029'; 'FAT030'; 'FAT032';
%     'FAT036';'FAT037';'FAT038';'FAT039';'FAT040';'FAT041';'FAT042';
%     'FAT043';'FAT044'};
% 
% testingSplit = IVAnalysis(ephysData,wtCells,fatCells);
% wtIVs = testingSplit{1};
% fatIVs = testingSplit{2};
% 
% clear testingSplit wtCells fatCells

allIVs = IVAnalysis(ephysData,allCells);
allIVs = IVRsCorrection(ephysData,allIVs,allCells);

%% Correct voltage steps based on series resistance and plot as scatter
% (OLD, use above cell)
% 
% wtCells = {'FAT020';'FAT021';'FAT022';'FAT025';'FAT031'; 'FAT033';'FAT034';'FAT035'};
% fatCells = {'FAT027';'FAT028';'FAT029'; 'FAT030'; 'FAT032';
%     'FAT036';'FAT037';'FAT038';'FAT039';'FAT040';'FAT041';'FAT042';
%     'FAT043'};
% % FAT044 has no OC
% 
% wtIVs = IVRsCorrection(ephysData,wtIVs,wtCells);
% fatIVs = IVRsCorrection(ephysData,fatIVs,fatCells);
% 
% wtI = [];
% wtV = [];
% fatI = [];
% fatV = [];
% 
% for i = 1:length(wtCells)
%     cellName = wtCells{i};
%     wtV = [wtV;wtIVs.(cellName).actualV'];
%     wtI = [wtI;wtIVs.(cellName).meanI'];
% end
% 
% for i = 1:length(fatCells)
%     cellName = fatCells{i};
%     fatV = [fatV;fatIVs.(cellName).actualV'];
%     fatI = [fatI;fatIVs.(cellName).meanI'];
% end
% 
% figure()
% hold on;
% scatter(wtV*1E3,wtI*1E12);
% scatter(fatV*1E3,fatI*1E12,'d');
% plotfixer;
% % FAT027 and FAT030 are the weird ones
% clear i cellName
%% Plot mechanically evoked currents in response to single steps
% IdAnalysis

wtCells = {'FAT034';'FAT035'};
fatCells = {'FAT036';'FAT038';'FAT042';'FAT043';'FAT044'};
% FAT041 has high leak

mechPeaksWT = IdAnalysis(ephysData,wtCells);
mechPeaksFat = IdAnalysis(ephysData,fatCells);


%% Make list of approved traces (by selecting traces to exclude)

protList = 'DispRate';
% protList = 'WC_Probe';
% protList = {'WC_Probe';'DispRate'};
ExcludeSweeps(ephysData,allCells,protList,'first');


%% Look at interstimulus interval
% allCells = {'FAT059'; 'FAT061';'FAT062';'FAT063'};
%     
% ISIs = ISIAnalysis(ephysData,allCells);
% 
int1sCells = {'FAT059'; 'FAT061';'FAT062';'FAT063';'FAT064'};
int3sCells = {'FAT065';'FAT066';'FAT072';'FAT073';'FAT077'};

isi1s = ISIAnalysis(ephysData,int1sCells,'WC_Probe8');
isi3s = ISIAnalysis(ephysData,int3sCells,'WC_Probe8_3s');

for i = 1:5
    clear a
    a(1,:)=isi1s{3,i}(1):1:isi1s{3,i}(1)+length(isi1s{1,i})-1;
    if size(isi1s{3,i},2)>1
        a(2,:)=isi1s{3,i}(2):1:isi1s{3,i}(2)+length(isi1s{1,i})-1;
    end
    tVec1{i}=reshape(a',[],1);
    iVecOn1{i} = reshape(isi1s{4,i}',[],1);
    iVecOff1{i} = reshape(isi1s{5,i}',[],1);
end

for i = 1:5
    clear a
    a(1,:)=isi3s{3,i}(1):1:isi3s{3,i}(1)+length(isi3s{1,i})-1;
    if size(isi3s{3,i},2)>1
        a(2,:)=isi3s{3,i}(2):1:isi3s{3,i}(2)+length(isi3s{1,i})-1;
    end
    tVec3{i}=reshape(a',[],1);
    iVecOn3{i} = reshape(isi3s{4,i}',[],1);
    iVecOff3{i} = reshape(isi3s{5,i}',[],1);
end

figure(); 
h1s = subplot(1,2,1); hold on;
h3s = subplot(1,2,2); hold on;

for i=1:5
    plot(h1s,tVec1{i},iVecOn1{i},'b');
    plot(h1s,tVec1{i},iVecOff1{i},'r');
    plot(h3s,tVec3{i},iVecOn3{i},'b');
    plot(h3s,tVec3{i},iVecOff3{i},'r');    
end
%% Plot single MRC sets
% Draw stim protocol for MRCs
dt = 0.2; % ms, based on sampling frequency (5kHz in current WC_Probe)
tVec = 0:dt:500-dt;
dVec = zeros(length(tVec),12);

% for i = 1:6
%     dVec(50/dt:250/dt,i)=1+2*(i-1);
% end
% 
% figure()
% plot(tVec,dVec,'r');
% plotfixer;

% Get data
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,1);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,2);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,3);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,4);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,5);
% plot(tVec,toPlot/1E-12);
% figure()
% toPlot = ephysData.FAT030.data{1,59}(:,6);
% plot(tVec,toPlot/1E-12);

figure()
toPlot = ephysData.FAT029.data{1,11}(:,6);
plot(tVec,toPlot/1E-12,'b');
plotfixer;


%% Dt 
allCells = {'FAT032'};

OnDtTest = OnDtAnalysis(ephysData,allCells);

figure()
scatter(OnDtTest.FAT032.dts,mean(OnDtTest.FAT032.on1))
hold on;
scatter(OnDtTest.FAT032.dts,mean(OnDtTest.FAT032.on2),'d')
scatter(OnDtTest.FAT032.dts,mean(OnDtTest.FAT032.off),'s')


%% Look at current clamp
allCells = fieldnames(ephysData);

for iCell = 1:length(allCells)
    cellName = allCells{iCell}; %split into project name and cell numbers when feeding input
    
    % UPDATE: after June/July 2014 (FAT025), Patchmaster has separate pgfs for
    % 'OC_ct_neg' and 'WC_ct_neg' to make it easier to pull out only capacity
    % transients of interest without having to check the notebook.
    protName = 'cc_gapfree';
    % two alternatives for finding instances of the desired protocol
    % find(~cellfun('isempty',strfind(ephysData.(cellName).protocols,'ct_neg')));
    protLoc = find(strncmp(protName,ephysData.(cellName).protocols,6));
    
    if protLoc
        for i = 1:length(protLoc)
            gapfree(:,i) = ephysData.(cellName).data{1,protLoc(i)};
        end
        basalVoltage{iCell} = gapfree;
    end
end

clear allCells iCell cellName protName protLoc i gapfree;


%% Check linearity of photodiode response

% % Import file '150702_photodiodetest1.dat', then:
% testMed = ephysData.E1.data{3,43};
% testSml = ephysData.E1.data{3,45};
% testLrg = ephysData.E1.data{3,44};

testMedBase = mean(testMed(1:500,:));
testMedStep = mean(testMed(1000:2000,:));
testMedSub = testMedStep-testMedBase;

testSmlBase = mean(testSml(1:500,:));
testSmlStep = mean(testSml(1000:2000,:));
testSmlSub = testSmlStep-testSmlBase;

testLrgBase = mean(testLrg(1:500,:));
testLrgStep = mean(testLrg(1000:2000,:));
testLrgSub = testLrgStep-testLrgBase;

controlStim = [1 3 5 7 9 11 0.5 1.5 8 10];
pdResp = [testMedSub testSmlSub testLrgSub];
toExcel = [controlStim; pdResp]';

scatter(controlStim, pdResp);