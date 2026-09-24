function RAVEN_V1_01_core()

clc;
close all force;
rng(2468,'twister');

app = struct();
app.cfg   = makeDefaultConfig();
app.state = struct('isRunning',false,'isPaused',false,'stopRequested',false, ...
                   'currentStep',0,'data',[],'results',struct(),'runTic',[], ...
                   'selectedFiles',{{}},'detectedData',[],'detectedSource','', ...
                   'lastAutoTuneSignature','', ...
                   'summaryPairs',{{}},'livePairs',{{}});

createUI();
setSummary('Preset','Accurate');
setLiveStatus('Preset','Accurate');
refreshPlan();
refreshLiveStatusContext();
logmsg('RAVEN_V1_01 ready.');
showLogo();
updateUploadedFilesList();
