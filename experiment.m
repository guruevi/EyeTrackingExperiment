function experiment()

%------------------------SET PARAMETERS HERE----------------------------%
% Set button response box settings here
triggerKey = '`~'; %223; %keycode for grave accent on RCBI stimulus computer.

% Set Eyetracker setting
useEyetracker = 1; %set to 1 if using the eyetracker; set to 0 if not (debug)

%Paths to Eyetracker dynamic libraries and headers
%vpxDylib is where the library lives on a Mac
%vpxDL is where the DLL lives on a Windows machine
vpxDylib    = '/usr/local/lib/libvpx_interapp.dylib';
%vpxDL      = 'Your\InstallPath\Viewpoint\vpx_interapp.dll';
vpxToolboxH = '/Applications/ViewPoint/SDK/vpxtoolbox.h';
vpxH        = '/Applications/ViewPoint/SDK/vpx.h';

%vpxServer is the ip (string) for the eyetracker, vpxServerPort is the port
vpxServer = '128.151.188.16';
vpxServerPort = 5000;
vpxNumCalibrationPoints = 6;

% Set required toolboxes
%Path to toolboxes. You'll need at least PsychToolbox and the Viewpoint
%toolbox. This script will automatically add them to your path.
if (exist('Screen', 'file') ~= 3)
    addpath(genpath('/Applications/PsychToolbox'))
end
if (useEyetracker && exist('vpx_Initialize', 'file') ~= 2)
    addpath(genpath('/Applications/ViewPoint/Interfaces/MATLAB'))
end

%scrID=max(Screen('Screens')); % which screen  to display
scrID=min(Screen('Screens'));

numTR = 5; %number of TR before the start of a block (for scanner)

%-------------------------END PARAMETER SETUP-------------------------%
%------ONLY MODIFY BELOW THIS LINE IF YOU KNOW WHAT YOU'RE DOING------%


%***Include paths for toolboxes------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%***Pre-Initialization---------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize keys used (routines)
KbName('UnifyKeyNames');
space=KbName('space');
trigger=KbName(triggerKey);

% Initialize eyetracker (ViewPoint routines)
if useEyetracker
    % It's always a good idea to put independent routines in separate
    % functions, that way it's easier to read your code and easier to
    % troubleshoot.
    initializeEyetracker()
end

% Initialize screen (PsychToolbox routines)
Screen('Preference', 'VisualDebugLevel', 0);
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'AllViews', 'EnableCLUTMapping');
[w rect] = Screen('OpenWindow', scrID, 0);
HideCursor;
%ifi=Screen('GetFlipInterval',w);

% Color Definitions (PsychToolbox routines)
black = BlackIndex(scrID);
white = WhiteIndex(scrID);
gray = white/2;

% Set this program to Max Priority in systems that allow this
Priority(MaxPriority(w));

% Initialize the rest of your program here...

%***Start Experiment---------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Record the time
sessionStartTime = GetSecs();

% Show Instructions (PsychToolbox routines)
Screen('FillRect', w, gray);
Screen(w,'TextSize',24);
Screen(w,'TextFont','Arial');

instructionText = 'Welcome to the experiment <explain task here>. Press space to continue';
DrawFormattedText(w, instructionText, 'center','center', 0);
Screen(w,'Flip',0,1); % show instruction
checkKey(space);


% Start Calibration (Viewpoint routines)
if useEyetracker
    % It's always a good idea to put independent routines in separate
    % functions, that way it's easier to read your code and easier to
    % troubleshoot.
    calibrateEyes()
end

% Start Trials
triggerCount = 0;
while triggerCount < numTR + 1
    % Choose a value well under the actual trigger rate and signal plateau
    % but slightly over the refresh frequency of the USB keyboard
    % so I chose 50ms. For more precise measurements, measure more often.
    WaitSecs (0.05);
    % If you're debugging with human fingers (increase to 500ms)
    % WaitSecs (0.5);
    
    if triggerCount ~= numTR
        % This is untested but this should set the timeout to the next flip
        % of the screen's buffer. I don't know if this will work correctly
        % but this will be more precise than WaitSecs
        Screen('Flip', w, 0, 1);
    else
        Screen('Flip', w);
    end
    
    checkTrigger();
    
    blockStartTime = GetSecs;
    triggerCount = triggerCount + 1;
    
    % Once the scanner indicates a start condition.
    if triggerCount == 1
        % Record the scanner start time
        recordEvent ('started session', blockStartTime, sessionStartTime);
    end
    
    % Record every trigger after that
    recordEvent('trigger received', blockStartTime, sessionStartTime);
end

%end of session text
DrawFormattedText(w, 'Session Complete. Thank you! Press space to continue', 'center','center', 0);
Screen('Flip', w);
checkKey(space);

%close Eyetracker gracefully
if useEyetracker
    closeEyetracker()
end

WaitSecs(1);
Screen('CloseAll');
clear PsychImaging;
Priority(0);

%*** Sub-Functions----------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% ViewPoint eyetracking functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%---------------------------Initialize eyetracker---------------------%

    function initializeEyetracker()
        %-- substitute vpxDL for vpxDylib when running on windows
        if ismac
            vpx_Initialize( vpxDylib, vpxToolboxH, vpxH);
            %-- need to connect if run on a Mac
            ret = vpx_ConnectToViewPoint(vpxServer, vpxServerPort);
            if ret ~= 0 && ret ~= 1
                error ('Experiment:InitializeEyetracker', 'Could not connect to EyeTracker server, Error # %d', ret);
            end
        elseif iswin
            vpx_Initialize( vpxDL, vpxToolboxH, vpxH);
            %-- no need to connect if run on Win? How does it detect?
            %-- not tested - see documentation
        else
            error ('Experiment:InitializeEyetracker', 'Other platforms not (yet) implemented');
        end
        
    end
%----------------------Calibrate Eyes---------------------------------%

    function calibrateEyes()
        vpx_Calibrate(vpxNumCalibrationPoints);
    end

%----------------------Close eyetracker---------------------------------%
    function closeEyetracker()
        % need to disconnect if run from a Mac
        vpx_DisconnectFromViewPoint();
        vpx_Unload();
    end

%----------------------Data logger---------------------------------%
    function recordEvent(eventDescr, blockStartTime, sessionStartTime)
        % for now we just output
        timestamp = blockStartTime - sessionStartTime;
        output = [eventDescr, timestamp];
        output
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%----------------------------Keyboard Checks------------------------%
% Check the keyboard to see if the trigger was sent; will return trigger as
% true if at this point, the trigger was sent
    function [ triggerSent ] = checkTrigger()
        triggerSent = checkKey (trigger);
    end

% Check the keyboard to see if any key was sent
    function [ key ] = checkKey(keyCode)
        key = 0;
        while ~key
            [~ , ~, kcode] = KbCheck(-3);
            if (find(kcode) == keyCode)
                key = 1;
            end
        end
    end
end
