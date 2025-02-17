% Sequence AO Plane Waves JB 30-04-15 ( d'apres 01-04-2015 JB)
% INITIALIZATION of the US Sequence
% ATTENTION !! M�me si la s�quence US n'�coute pas, il faut quand m�me
% d�finir les remote.fc et remote.rx, ainsi que les rxId des events.
% DO NOT USE CLEAR OR CLEAR ALL use clearvars instead
function [SEQ,Delay,MedElmtList,AlphaM] = AOSeqInit_OP(AixplorerIP, Volt , f0 , NbHemicycle , AlphaM , dA , X0 , X1 ,Prof, NTrig)
 clear ELUSEV EVENTList TWList TXList TRIG ACMO ACMOList SEQ
% user defined parameters :

    ScanLength      = X1 - X0; % mm
    
% creation of vector for scan:       
if dA > 0
    AlphaM = sort(-abs(AlphaM):dA:abs(AlphaM));   % Planes waves angles (deg) 
end

%% System parameters import :
% ======================================================================= %
c           = common.constants.SoundSpeed ; % [m/s]
SampFreq    = system.hardware.ClockFreq;   % NE PAS MODIFIER % emitted signal sampling = 180 in [MHz]
NbElemts    = system.probe.NbElemts ; 
pitch       = system.probe.Pitch ;          % in mm
MinNoop     = system.hardware.MinNoop;

NoOp       = 500;             % �s minimum time between two US pulses

% ======================================================================= %

PropagationTime        = Prof/c*1e3 ;   % 1 / pulse frequency repetition [us]
TrigOut                = 10;            % �s
Pause                  = max( NoOp - ceil(PropagationTime) , MinNoop ); % pause duration in �s

% ======================================================================= %
%% Codage en arbitrary : delay matrix and waveform
dt_s          = 1/(SampFreq);  % unit us
pulseDuration = NbHemicycle*(0.5/f0) ; % US inital pulse duration in us


% ======================================================================= %
%% Codage en arbitrary : delay matrix and waveform
% if ScanLength==0 || round(ScanLength/pitch)>=NbElemts    
%     Nbtot = NbElemts;
% else  
%     Nbtot = round(ScanLength/pitch);    
% end

   Nbtot = NbElemts;


Delay = zeros(Nbtot,length(AlphaM)); %(�s)

for i = 1:length(AlphaM)
    
%     Delay(:,i) = 1000*sin(pi/180*AlphaM(i))*(1:Nbtot)*pitch/(c); 
    
    Delay(:,i) = 1000*(1/c)*tan(pi/180*AlphaM(i))*(1:Nbtot)*(pitch); %s
    Delay(:,i) = Delay(:,i) - min(Delay(:,i));
    
end
 
% for i = 1:length(AlphaM)
%     % setting absolute maximum delay for as reference for 0 angle ..?
%     Delay(:,i) = Delay(:,i) - max(Delay(:,i)); 
%     Delay(:,i) = Delay(:,i) + max(Delay(:));
%     
% end


DlySmpl = round(Delay/dt_s); % conversion in steps

% waveform
T_Wf = 0:dt_s:pulseDuration;
Wf = sin(2*pi*f0*T_Wf);

N_T = length(Wf) + 0*max(max(DlySmpl));

%WF_mat = repmat(Wf,1,1:length(Nbtot));
WF_mat = zeros(N_T,Nbtot,length(AlphaM));

for angle = 1:length(AlphaM)
    for element = 1:Nbtot
      phase_offset = 0*DlySmpl(element,angle);
      WF_mat( phase_offset + (1:length(Wf)),element,angle) = Wf;
    end
end

WF_mat_sign = sign(WF_mat); % l'aixplorer code sur 2 niveaux [-1,1]
WF_mat_sign0 = sign(Wf); % l'aixplorer code sur 2 niveaux [-1,1]

% ======================================================================= %
%% Arbitrary definition of US events

FirstElmt  = max( round(X0/pitch),1);

MedElmtList = 1:length(AlphaM); % list of shot ordering for angle scan (used to reconstruct image)

EvtDur   = ceil(pulseDuration + max(max(Delay)) + PropagationTime);   




for nbs = 1:length(AlphaM)
    
    EvtDur   = ceil(pulseDuration + max(max(Delay)) + PropagationTime);   

    WFtmp    = squeeze( WF_mat_sign( :, :, nbs ) );
       
    % Flat TX, other parameters : 
    % 'tof2Focus': time of flight to focal point from the time origin of transmit [us]
    % 'TxElemts' : 'id of the TX channels' [1 system.probe.NbElemts]
    % % Delays for each tx elements
    
    
    TXList{nbs} = remote.tx_arbitrary(...
               'txClock180MHz', 1,...   % sampling rate = { 0 ,1 } = > {'90 MHz', '180 MHz'}
               'twId',1,...             % {0 [1 Inf]} = {'no waveform', 'id of the waveform'},
               'Delays',0,...
               0);                      
    
    % Arbitrary TW
    TWList{nbs} = remote.tw_arbitrary( ...
        'Waveform',WFtmp', ...
        'RepeatCH', 0, ...
        'repeat',0 , ...
        'repeat256', 0, ...
        'ApodFct', 'none', ...
        'TxElemts',FirstElmt:FirstElmt+Nbtot-1, ...
        'DutyCycle', 1, ...
        0);

end

% ELUSEV.arbitrary < elusev.elusev with additional parameters : 
% Waveform , for each tx elements [-1 1]
% Delays , for each tx elements (default = 0) [0 1000]
% Pause, pause duration after arbitrary events [us] [system.hardware.MinNoop 1e6]
% PauseEnd , pause duration at the end [us] [system.hardware.MinNoop 1e6]
% ApodFct , {'none' 'bartlett' 'blackman' 'connes' 'cosine' 'gaussian' 'hamming' 'hanning' 'welch'}
% RxFreq, reception frequency [MHz] [1 60]
% RxCenter receive center position [mm] [1 100]
% RxWidth , RxDuration , RxDelay , RxBandwidth , FIRBandwidth

    ELUSEV = elusev.arbitrary( ...
        'ARBITRARY' ,   'plane wave with delay matrix ', ...
        'tw',           TWList,...
        'Waveform',     WF_mat_sign0, ...
        'Delays',       Delay , ...
        'ApodFct',      'none', ...   
        'Pause',        EvtDur, ...
        'PauseEnd',     100, ...
        'RxFreq',       30, ...
        'RxDuration',   98, ...
        'RxDelay',      1, ...
        'RxCenter',     1, ...
        'RxWidth',      1, ...
        'RxBandwidth',  1, ...
        'TrigOut',      TrigOut, ...
        'TrigIn',       0,...
        'TrigAll',      1, ...
        'TrigOutDelay', 0, ...
        0);
    
% ======================================================================= %
%% ELUSEV and ACMO definition
% duration : sets the TGC duration [us] [0 inf] (default = 0)
% fastTGC : enables the fast TGC mode [0 1] (default = 0)
% Mode ('NbHostBuffer' = 2 , 'ModeRx' = 0)
% TGC ('Duration'= 0, 'ControlPts' = 900, 'fastTGC' = 0)
% DMA ('localBuffer'=0)

ACMO = acmo.acmo( ...
    'ACMO' , 'my personal sequence',...
    'elusev',           ELUSEV, ...
    'Ordering',         0, ...   % 'sets the ELUSEV execution order', {0 [1 Inf]} {'chronological ordering', 'customed ordering'}
    'Repeat' ,          1, ...   % ACMO repetition [1 Inf]
    'NbHostBuffer',     1, ...   % (default = 1) , [1 common.legHAL.RemoteMaxNbHostBuffers]
    'NbLocalBuffer',    1, ...   % sets the number of host buffers {0 [1 20]} , (default = 0 : automatic)
    'ControlPts',       900, ... % sets the value of TGC control points [0 960], default = 900
    'RepeatElusev',     1, ...   % sets the number of times all ELUSEV are repeated before data transfer [1 Inf] (default = 1)
    0);

ACMOList{1} = ACMO;

% ======================================================================= %
%% Build sequence

% Probe Param
% pushVoltage : sets maximum push voltage (8 80]
% pushCurrent : sets maximum push current [0 20]
TPC = remote.tpc( ...
    'imgVoltage', Volt, ... % sets maximum imaging voltage [8 80]
    'imgCurrent', 1, ...    % security limit for imaging current [0 2] [A]
    0);

% USSE for the sequence
% Ordering : ACMO execution order during the USSE {0 [1 Inf]}
SEQ = usse.usse( ...
    'USSE', 'Plane Wave waveforms',...% first argument is the name of the object
    'TPC', TPC, ... 
    'acmo', ACMOList, ...    'Loopidx',1, ...
    'Repeat', NTrig+1, ...  % sets the repetition number of USSE  [1 Inf].
    'DropFrames', 0, ...    % enables error message if acquisition were dropped : {0,1}
    'Loop', 0, ...          % 0 : sequence executed once, 1 : sequence looped
    'DataFormat', 'FF', ... % format output data : {'RF' 'BF' 'FF'}
    'Popup', 0, ...         % enables the popups to control the sequence execution : {0,1}
    0);                     % debugg parameter

[SEQ NbAcq] = SEQ.buildRemote();
 display('Build OK')
 
%%%    Do NOT CHANGE - Sequence execution 
%%%    Initialize remote on systems
 
 SEQ = SEQ.initializeRemote('IPaddress',AixplorerIP);

 display('Remote OK');

 % status :
 display('Loading sequence to Hardware');
 SEQ = SEQ.loadSequence();
 disp('-------------Ready to use-------------------- ')
 

end



