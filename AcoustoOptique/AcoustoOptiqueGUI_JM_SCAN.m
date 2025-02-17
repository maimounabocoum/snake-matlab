% clear all; close all; clc
% w = instrfind; if ~isempty(w) fclose(w); delete(w); end

%% parameter for plane wave sequence :
% ======================================================================= %
% adresse Jussieu : '192.168.1.16'
% adresse Bastille : '192.168.0.20'

 AixplorerIP    = '192.168.1.16'; % IP address of the Aixplorer device
 addpath('sequences');
 addpath('subfunctions');
 addpath('C:\Program Files (x86)\Gage\CompuScope\CompuScope MATLAB SDK\CsMl')
 addpath('D:\_legHAL_Marc')
 addPathLegHAL();
 
       TypeOfSequence = 'JM'; % 'OF' , 'OP' , 'JM'
    
    %   a=[];
    %   V=[];
       
 for ConsigneVolt=10:20;      
        Nloop = 1 ;
 
        Volt        = ConsigneVolt     % 'OF' , 'OP' , 'JM'
        FreqSonde   = 2;     % 'OF' , 'OP' , 'JM'
        NbHemicycle = 250;   % 'OF' , 'OP' , 'JM'
        Foc         = 25;    % 'OF' 
        AlphaM      = 20;    % 'OP' 
        dA          = 1;     % 'OP' 
        X0          = 5;    % 'OF' , 'OP'
        X1          = 30;    % 'OF' , 'OP' 
        NTrig       = 1000;   % 'OF' , 'OP' , 'JM'
        Prof        = 200;   % 'OF' , 'OP' , 'JM'
        NbZ         = 8;     % 4; % Nb de composantes de Fourier en Z, 'JM'
        NbX         = 10;     % 5 Nb de composantes de Fourier en X, 'JM'
        DurationWaveform = 20;
        
        SaveData = 1 ;      % set to 1 to save data
        AIXPLORER_Active = 'on'; % 'on' or 'off' 
 % estimation of loading time 
 % [NUX,NUZ] = evalNUs(NbX,NbZ,FreqSonde,SampleRate);

 fprintf('%i events, loading should take about %d seconds\n\r',(2*NbX+1)*NbZ,(2*NbX+1)*NbZ*3);

%% ============================   Initialize AIXPLORER
% %% Sequence execution
% % ============================================================================ %
if strcmp(AIXPLORER_Active,'on')
    switch TypeOfSequence
        case 'OF'
    [SEQ,MedElmtList] = AOSeqInit_OF(AixplorerIP, Volt , FreqSonde , NbHemicycle , Foc, X0 , X1 , Prof, NTrig);
        case 'OP'
    [SEQ,MedElmtList,AlphaM] = AOSeqInit_OP(AixplorerIP, Volt , FreqSonde , NbHemicycle , AlphaM , dA , X0 , X1 ,Prof, NTrig);
        case 'JM'
    Volt = min(Volt,15) ; 
    [SEQ,MedElmtList,NUX,NUZ] = AOSeqInit_OJML(AixplorerIP, Volt , FreqSonde , NbHemicycle , NbX , NbZ , X0 , X1 ,Prof, NTrig,DurationWaveform);

    end
end


c = common.constants.SoundSpeed ; % sound velocity in m/s
                    
%%  ========================================== Init Gage ==================
% Possible return values for status are:
%   0 = Ready for acquisition or data transfer
%   1 = Waiting for trigger event
%   2 = Triggered but still busy acquiring
%   3 = Data transfer is in progress

     
     SampleRate    =   10;
     Range         =   1;
     TriggerActive = 'on' ; % on to activate Gage external trig, off : will trig on Timeout value
     
    if strcmp(AIXPLORER_Active,'on') 
 Nlines = length(SEQ.InfoStruct.event);  
    else
        Nlines = (2*NbX+1)*NbZ ;
    end
 
[ret,Hgage,acqInfo,sysinfo,transfer] = InitOscilloGage(NTrig*Nlines,Prof,SampleRate,Range,TriggerActive);

raw   = zeros(acqInfo.Depth,acqInfo.SegmentCount);
    

    %% ======================== start acquisition =============================

    SequenceDuration_us = 1000;   
    Nloop = 1 ;
    % starts loop for data online screaning
    for Iloop = 1:Nloop
        
    ret = CsMl_Capture(Hgage);
    CsMl_ErrorHandler(ret, 1, Hgage);
    
     if strcmp(AIXPLORER_Active,'on')
    SEQ = SEQ.startSequence('Wait',0);
     end
    
    tic
    status = CsMl_QueryStatus(Hgage);
    tasks2execute = 0;
    while status ~= 0 && tasks2execute < NTrig*(SequenceDuration_us/50)*200000

        status = CsMl_QueryStatus(Hgage) ;
        tasks2execute = tasks2execute + 1; % increment to exit loop in case Gage would not trig
       
    end
    
    fprintf('Aquisition lasted %f s \n\r',toc);
    
     if strcmp(AIXPLORER_Active,'on')
    
    SEQ = SEQ.stopSequence('Wait', 0); 
    
    
     end
    
    % Transfer data to Matlab
    % Z  = linspace(0,Prof,acqInfo.Depth); 
    % loop over segment counts:

    
    
    tic 
    for SegmentNumber = 1:acqInfo.SegmentCount
        
        transfer.Segment       = SegmentNumber;                     % number of the memory segment to be read
        [ret, datatmp, actual] = CsMl_Transfer(Hgage, transfer);    % transfer
                                                                    % actual contains the actual length of the acquisition that may be
                                                                    % different from the requested one.
       raw((1+actual.ActualStart):actual.ActualLength,SegmentNumber) = datatmp' ;
        
    end
    CsMl_ErrorHandler(ret, 1, Hgage);
    
    fprintf('Data Transfer lasted %f s \n\r',toc);
    

    
    
     
    
    
    
%% ======================== data post processing =============================

    
    switch TypeOfSequence
        
        case 'OF'
            
    Datas = RetreiveDatas(raw,NTrig,Nlines,MedElmtList);
    z = (1:actual.ActualLength)*(c/(1e6*SampleRate))*1e3;
    x = (1:Nlines)*system.probe.Pitch;
    imagesc(x,z,1e3*Datas)
    xlabel('x (mm)')
    ylabel('z (mm)')
%     axis equal
%     axis tight

        case 'OP'
            
    Datas = RetreiveDatas(raw,NTrig,Nlines,MedElmtList);
    z = (1:actual.ActualLength)*(c/(1e6*SampleRate))*1e3;
    x = AlphaM;
    imagesc(x,z,1e3*Datas)
    xlabel('angle (�)')
    ylabel('z (mm)')
    title('Averaged raw datas')
    cb = colorbar;
    ylabel(cb,'AC tension (mV)')
    colormap(parula)
    set(findall(Hf,'-property','FontSize'),'FontSize',15) 


   % ylim([0 50])
   
   case 'JM'
       
        Datas = RetreiveDatas(raw,NTrig,Nlines,1:Nlines);
       % Calcul composante de Fourier
         z = (1:actual.ActualLength)*(c/(1e6*SampleRate))*1e3;
         x = (1:Nlines);
            Hfinal = figure(100);
            set(Hfinal,'WindowStyle','docked');
%            subplot(121)
            imagesc(x,z,1e3*Datas)
            %imagesc(1e3*Datas)
            xlabel('lines Nbx, Nbz')
            ylabel('z (mm)')    
            title('Averaged raw datas')
            cb = colorbar;
            ylabel(cb,'AC tension (mV)')
            colormap(parula)

       [I,X,Z] = Reconstruct(NbX , NbZ, ...
                             NUX , NUZ ,...
                             x , z , ...
                             Datas , ...
                             SampleRate , DurationWaveform, c , system.probe.Pitch*1e-3); 

     %   subplot(122)
     Hfinal = figure(101);
      set(Hfinal,'WindowStyle','docked');
       imagesc(X,Z,I);
       title('reconstructed image')
       xlabel('x (mm)')
       ylabel('z (mm)')
       cb = colorbar;
       ylabel(cb,'a.u')
       set(findall(Hfinal,'-property','FontSize'),'FontSize',15)
       
    end

    
    end
   
%% save datas :
%% save datas :
if SaveData == 1
MainFolderName = 'D:\Data\JM';
SubFolderName  = generateSubFolderName(MainFolderName);
CommentName    = 'Scan_SL102';
FileName       = generateSaveName(SubFolderName ,'name',CommentName,'TypeOfSequence',TypeOfSequence,'NbZ',NbZ,'NbX',NbX,'Volt',Volt);


save([FileName],'Volt','FreqSonde','NbHemicycle','Foc','DurationWaveform','NbZ','NbX','x','z','NUZ','NUX',...
               'X0','X1','NTrig','Nlines','Prof','MedElmtList','I','Datas','SampleRate','c','Range','TypeOfSequence');
savefig(Hfinal,FileName);
saveas(Hfinal,FileName,'png');

fprintf('Data has been saved under : \r %s \r\n',FileName);

end

a=[a sum(sum(I))];
V=[V Volt];
 end

%% ================================= command line to force a trigger on Gage :
%  CsMl_ForceCapture(Hgage);
%% ================================= quite remote ===========================================%%
%            SEQ = SEQ.quitRemote();

