% Bandits
% C. Hassall
% January, 2018

%% Standard Krigolson Lab pre-script code
close all; clear variables; clc; % Clear everything
rng('shuffle'); % Shuffle the random number generator

%% Run flags
justTesting = 0;
windowed = 0;
useDatapixx = 1;

%% DataPIXX Setup
if useDatapixx
    Datapixx('Open');
    Datapixx('StopAllSchedules');
    
    % We'll make sure that all the TTL digital outputs are low before we start
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    
    % Configure digital input system for monitoring button box
    Datapixx('EnableDinDebounce');                          % Debounce button presses
    Datapixx('SetDinLog');                                  % Log button presses to default address
    Datapixx('StartDinLog');                                % Turn on logging
    Datapixx('RegWrRd');
end

%% Define control keys
KbName('UnifyKeyNames'); % Ensure that key names are mostly cross-platform
ExitKey = KbName('ESCAPE'); % Exit program
    
%% Display Settings
% Lab
viewingDistance = 600; % mm, approximately
screenWidth = 477; % mm
screenHeight = 268; % mm
horizontalResolution = 1920; % Pixels
verticalResolution = 1080; % Pixels

% Cam's office (iMac)
% viewingDistance = 700; % mm, approximately MARGE
% screenWidth = 180; % mm MARGE
% screenHeight = 140; % mm MARGE
% horizontalResolution = 2560; % Pixels MARGE
% verticalResolution = 1440; % Pixels MARGE

% Cam's laptop (Macbook Air)
% viewingDistance = 560; % mm, approximately BOB
% screenWidth = 286; % mm BOB
% screenHeight = 179; % mm BOB
% horizontalResolution = 1440; % Pixels BOB
% verticalResolution = 980; % Pixels BOB

% Set up window
if windowed
    displayRect = [300 300 1000 800]; % Testing window
else
    displayRect = [0 0 horizontalResolution verticalResolution];
end
windowWidth = ((displayRect(3)-displayRect(1))/horizontalResolution)*screenWidth;
windowHeight = ((displayRect(4)-displayRect(2))/verticalResolution)*screenHeight;

% Compute pixels per mm
horizontalPixelsPerMM = (displayRect(3)-displayRect(1))/windowWidth;
verticalPixelsPerMM = (displayRect(4)-displayRect(2))/windowHeight;

%% Participant info and data
participantData = [];
if justTesting
    p_number = '99';
    rundate = datestr(now, 'yyyymmdd-HHMMSS');
    filename = strcat('bandits _', rundate, '_', p_number, '.txt');
    mfilename = strcat('bandits _', rundate, '_', p_number, '.mat');
    sex = 'FM';
    age = '99';
    handedness = 'LR';
else
    while 1
        clc;
        p_number = input('Enter the participant number:\n','s');  % get the subject name/number
        rundate = datestr(now, 'yyyymmdd-HHMMSS');
        filename = strcat('bandits_', rundate, '_', p_number, '.txt');
        mfilename = strcat('bandits _', rundate, '_', p_number, '.mat');
        checker1 = ~exist(filename,'file');
        checker2 = isnumeric(str2double(p_number)) && ~isnan(str2double(p_number));
        if checker1 && checker2
            break;
        else
            disp('Invalid number, or filename already exists.');
            WaitSecs(1);
        end
    end
    sex = input('Sex (M/F): ','s');
    age = input('Age: ');
    handedness = input('Handedness (L/R): ','s');
end
ListenChar(0);

%% Parameters
bgColour = [0 0 0];
textColour = [255 255 255];
lineColour = [255 255 255];
lineWidth = 3; % Pixels

stimSpacingDeg = 6;
stimSpacingMM = 2 * viewingDistance *tand(stimSpacingDeg/2);
stimSpacingPx = stimSpacingMM * horizontalPixelsPerMM;

banditSpacingDeg = 1;
banditSpacingMM = 2 * viewingDistance *tand(banditSpacingDeg/2);
banditSpacingPx = banditSpacingMM * horizontalPixelsPerMM;
banditOutlineColour = [255 255 255];

banditWidthDeg = 0.5;
banditWidthMM = 2 * viewingDistance *tand(banditWidthDeg/2);
banditWidthPx = banditWidthMM * horizontalPixelsPerMM;

payoutWidthDeg = 1;
banditSpacingMM = 2 * viewingDistance *tand(payoutWidthDeg/2);
payoutSpacingPx = banditSpacingMM * horizontalPixelsPerMM;
payoutSpacingPt = round(payoutSpacingPx * (72/96));

banditColours = Shuffle(lines);
% banditColours = Shuffle(colormap('hsv'));

% Run Time
% Approx. 2.7657 per trial
% 3*150*2.7657/60 = 20-21 minutes
nBlocks = 3;
nBandits = [4 9 16]; % Length should match nBlocks. Items should be perfect squares
nTrials = 300; % Trials per block

% From the Daw paper
decayParameter = 0.9836;
decayCenter = 50;
diffusionNoiseSD = 2.8;
payoutSD = 4;

% Compute mean payouts
meanPayouts = {};
for b = 1:length(nBandits)
    theseMus = nan(nBandits(b),nTrials);
    % theseMus(:,1) = round(50 + 4*randn(nBandits,1));
    theseMus(:,1) = 100*rand(nBandits(b),1);
    for i = 2:nTrials
        theseMus(:,i) = decayParameter*theseMus(:,i-1) + (1-decayParameter)*decayCenter + diffusionNoiseSD*randn(nBandits(b),1);
    end
    theseMus(theseMus < 1) = 1;
    theseMus(theseMus > 100) = 100;
    meanPayouts{b} = theseMus;
end

% Compute actual payouts
actualPayouts = {};
for b = 1:length(nBandits)
    theseMeanPayouts = meanPayouts{b};
    thisNoise = payoutSD.*randn(nBandits(b),nTrials);
    theseActualPayouts = round(theseMeanPayouts + thisNoise);
    theseActualPayouts(theseActualPayouts<1) = 1;
    theseActualPayouts(theseActualPayouts>100) = 100;
    actualPayouts{b} = theseActualPayouts;
end

% % Check
% for b = 1:length(nBandits)
%     subplot(1,length(nBandits),b);
%     plot(meanPayouts{b}');
%     hold on;
%     plot(actualPayouts{b}','--');
% end

% Randomize block order, for now (TODO: counterbalance)
switch mod(str2double(p_number),factorial(nBlocks))
    case 1
        blockOrder = [3 2 1];
    case 2
        blockOrder = [3 1 2];
    case 3
        blockOrder = [2 3 1];
    case 4
        blockOrder = [2 1 3];
    case 5
        blockOrder = [1 3 2];
    case 0
        blockOrder = [1 2 3];
    otherwise
        blockOrder = randperm(3);
end

%% Experiment
try
    if windowed
        [win, rec] = Screen('OpenWindow', 0, bgColour,displayRect, 32, 2);
    else
        Screen('Preference', 'SkipSyncTests', 1);
        [win, rec] = Screen('OpenWindow', 0, bgColour);
    end
    Screen('BlendFunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    horRes = rec(3);
    verRes = rec(4);
    xmid = round(rec(3)/2);
    ymid = round(rec(4)/2);
    
    banditXCenters = {};
    banditYCenters = {};
    banditRects = {};
    banditWidths = [];
    % Compute the bandit centers
    for b = 1:length(nBandits)
        theseXCenters = [];
        theseYCenters = [];
        theseRects = [];
        for r = 1:sqrt(nBandits(b))
            thisRow = [];
            thisYRow = [];
            shiftBy = sqrt(nBandits(b))/2 + 1/2;
            banditSpacingPx = stimSpacingPx/sqrt(nBandits(b));
            banditWidths(b) = stimSpacingPx/sqrt(nBandits(b));
            for c = 1:sqrt(nBandits(b))
                thisXCenter = xmid + (c - shiftBy)*banditSpacingPx;
                thisYCenter = ymid + (r - shiftBy)*banditSpacingPx;
                thisRow = [thisRow thisXCenter];
                thisYRow = [thisYRow thisYCenter];
                thisCenter = [thisXCenter thisYCenter]; % Includes offset
                theseRects = [theseRects; thisCenter(1) - banditWidths(b)/2 thisCenter(2) - banditWidths(b)/2 thisCenter(1) + banditWidths(b)/2 thisCenter(2) + banditWidths(b)/2];
                theseXCenters(r,c) = thisXCenter;
                theseYCenters(r,c) = thisYCenter;
            end
        end
        
        theseRects = [];
        for c = 1:sqrt(nBandits(b))
            for r = 1:sqrt(nBandits(b))
                theseRects = [theseRects; theseXCenters(r,c) - banditWidths(b)/2 theseYCenters(r,c) - banditWidths(b)/2 theseXCenters(r,c) + banditWidths(b)/2 theseYCenters(r,c) + banditWidths(b)/2];
            end
        end
        
        banditXCenters{b} = theseXCenters;
        banditYCenters{b} = theseYCenters;
        banditRects{b} = theseRects;
    end
    
    % Load sample images
    twoImage = imread('./images/twoexample.png');
    twoTexture = Screen('MakeTexture', win, twoImage);
    twoSize = [385 405];
    twoLocation = [xmid ymid + 300];
    twoRect = ceil([twoLocation(1)-twoSize(1)/2  twoLocation(2)-twoSize(2)/2 twoLocation(1)+twoSize(1)/2 twoLocation(2)+twoSize(2)/2]);
    fourImage = imread('./images/fourexample.png');
    fourTexture = Screen('MakeTexture', win, fourImage);
    fourSize = [386 405];
    fourLocation = [xmid ymid + 300];
    fourRect = ceil([fourLocation(1)-fourSize(1)/2  fourLocation(2)-fourSize(2)/2 fourLocation(1)+fourSize(1)/2 fourLocation(2)+fourSize(2)/2]);
    
    % Instructions 
    instructions{1} = 'SLOT MACHINES\nYour goal in this experiment is to win as many points as possible by playing several slot machines\nEach slot machine pays out a point amount ranging from 1 to 100\nAlthough payouts are somewhat random, the average payout differs for each slot machine\nOver time, the average payouts slowly change\nIn other words, the best choice may change over time';
    instructions{4} = 'TASK DETAILS\nThe number of slot machines will vary (four, nine, or sixteen)\nUse the mouse to pick a slot machine\nFor each set of slot machines you will play 300 rounds';
    instructions{2} = 'EXAMPLE ONE\nHere is an example of two slot machines, represented by coloured squares\nInitially, the orange slot machine is better because it has a higher average payout (see graph).\nOver time though, the blue slot machine becomes the better choice (then orange again at the end)';
    instructions{3} = 'EXAMPLE TWO\nHere is an example of four slot machines\nThe yellow slot machine is the best choice in beginning, but it is overtaken by the grey slot machine\nNote that these are just examples and that during the actual experiment the colours and payouts will be randomly generated';
    instructions{5} = 'EEG QUALITY\nPlease try to minimize eye and head movements\nAfter choosing a slot machine, your choice will be highlighted in white\nA point amount will then be briefly displayed within your chosen slot machine\nPlease remain fixated on the points until they disappear\nIf you are too slow to respond, the message "too slow" will be displayed and we will not count that round\nYou will be given several rest breaks\nPlease use these opportunities to rest your eyes, as needed';
    instructions{6} = 'SUMMARY\nUse the mouse to pick a slot machine\nPoints (1-100) will appear within your choice - wait for the points to disappear before looking away\nEach slot machine''s average payout slowly changes across 300 rounds';
    
    Screen('TextSize',win,18);
    DrawFormattedText(win,[instructions{1} '\n\n(press any key to continue)'],'center','center',[255 255 255]);
    Screen('Flip',win);
    KbReleaseWait(-1);
    KbPressWait(-1);
    
    Screen('TextSize',win,18);
    Screen('DrawTexture', win, twoTexture,[],twoRect);
    DrawFormattedText(win,[instructions{2} '\n\n(press any key to continue)'],'center','center',[255 255 255]);
    Screen('Flip',win);
    KbReleaseWait(-1);
    KbPressWait(-1);
    
    Screen('TextSize',win,18);
    Screen('DrawTexture', win, fourTexture,[],fourRect);
    DrawFormattedText(win,[instructions{3} '\n\n(press any key to continue)'],'center','center',[255 255 255]);
    Screen('Flip',win);
    KbReleaseWait(-1);
    KbPressWait(-1);
    
    Screen('TextSize',win,18);
    DrawFormattedText(win,[instructions{4} '\n\n(press any key to continue)'],'center','center',[255 255 255]);
    Screen('Flip',win);
    KbReleaseWait(-1);
    KbPressWait(-1);
    
    Screen('TextSize',win,18);
    DrawFormattedText(win,[instructions{5} '\n\n(press any key to continue)'],'center','center',[255 255 255]);
    Screen('Flip',win);
    KbReleaseWait(-1);
    KbPressWait(-1);
    
    Screen('TextSize',win,18);
    DrawFormattedText(win,[instructions{6} '\n\n(press any key to begin the experiment)'],'center','center',[255 255 255]);
    Screen('Flip',win);
    KbReleaseWait(-1);
    KbPressWait(-1);
    
    % Initialize choice and RT variables
    participantChoices = nan(nBandits(b),nTrials);
    participantRTs = nan(nBandits(b),nTrials);
    
    % Block/trial loop
    for b = blockOrder
        
        % Get actual payouts for this block
        thesePayouts = actualPayouts{b};
        
        % Get bandit locations for this block
        xCenters = banditXCenters{b}(:);
        yCenters = banditYCenters{b}(:);
        
        % Block start message
        Screen(win,'TextFont','Arial');
        Screen(win,'TextSize',24);
        Screen('TextStyle',win,0);
        DrawFormattedText(win,'new slot machines - get ready','center','center',textColour);
        Screen('Flip',win);
        WaitSecs(2);
        
        % Trial loop
        for t = 1:nTrials
            ShowCursor();
            
            % Show bandits (until response)
            for r = 1:nBandits(b)
                Screen('FillRect',win,255*banditColours(r,:),banditRects{b}(r,: ));
            end
            flipandmark(win,b,useDatapixx);
            
            % Get response (up to two seconds)
            validClick = 0;
            startTime = GetSecs();
            ellapsedTime = GetSecs() - startTime;
            while ~validClick && ellapsedTime < 2
                [x,y,buttons] = GetMouse(win);
                if any(buttons)
                    myDistances = sqrt((x - xCenters).^2 + (y - yCenters).^2);
                    [myMin, closest] = min(myDistances);
                    validClick = myMin < sqrt((banditWidths(b)/2)^2 + (banditWidths(b)/2)^2); % Participant must get within 100 pixels of center
                end
                ellapsedTime = GetSecs() - startTime;
            end
            
            if validClick
                participantChoices(b,t) = closest;
                
                % Compute payout
                thisPayout = actualPayouts{b}(closest,t);
                
                % Compute payout marker
                % 11 - 20 condition 1
                % 21 - 30 condition 2
                % 31 - 40 condition 3
                thisPayoutMarker = b*10 + ceil(thisPayout/10);
                
                % Highlight choice and hide cursor
                HideCursor();
                for r = 1:nBandits(b)
                    Screen('FillRect',win,255*banditColours(r,:),banditRects{b}(r,: ));
                    Screen('FrameRect',win,[255 255 255],banditRects{b}(closest,: ),3);
                end
                flipandmark(win,255, useDatapixx); % "fixation cross"
                WaitSecs(0.4 + rand*0.2); % 400-600 ms delay
                
                for r = 1:nBandits(b)
                    Screen('FillRect',win,255*banditColours(r,:),banditRects{b}(r,: ));
                    Screen('FrameRect',win,[255 255 255],banditRects{b}(closest,: ),3);
                end
                Screen('TextFont',win,'Arial');
                Screen('TextStyle',win,1);
                Screen('TextSize',win,payoutSpacingPt);
                %DrawFormattedText(win,num2str(thisPayout),xCenters(closest)-payoutSpacingPx/2,yCenters(closest)+payoutSpacingPx/2,textColour);
                DrawFormattedText(win,num2str(thisPayout),'center','center',textColour,[],0,0,1,0,banditRects{b}(closest,: ));
                flipandmark(win,thisPayoutMarker,useDatapixx);
                WaitSecs(1);
                
            else % Display "too slow"
                closest = NaN;
                thisPayout = NaN;
                for r = 1:nBandits(b)
                    Screen('FillRect',win,255*banditColours(r,:),banditRects{b}(r,: ));
                end
                Screen(win,'TextFont','Arial');
                Screen('TextStyle',win,1);
                Screen(win,'TextSize',24);
                DrawFormattedText(win,'too slow','center','center',textColour);
                flipandmark(win,254,useDatapixx);
                WaitSecs(1);
            end
            
            % Check for escape key
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyCode(ExitKey)
                ME = MException('kh:escapekeypressed','Exiting script');
                throw(ME);
            end
            
            thisLine = [b t ellapsedTime validClick closest thisPayout];
            dlmwrite(filename,thisLine,'delimiter', '\t', '-append');
            participantData = [participantData; thisLine];
            
            % Rest break
            if t == nTrials/2
                Screen(win,'TextFont','Arial');
                Screen(win,'TextSize',24);
                Screen('TextStyle',win,0);
                DrawFormattedText(win,'rest break - press any key to continue','center','center',textColour);
                Screen('Flip',win);
                KbPressWait();
            end
        end
    end
    toc
    
    % Save important variables
    save(mfilename, 'banditColours', 'nBandits', 'meanPayouts', 'actualPayouts','blockOrder', 'participantChoices','participantRTs','participantData');
    
    % End of Experiment
    Screen(win,'TextFont','Arial');
    Screen(win,'TextSize',24);
    DrawFormattedText(win,'end of experiment - thank you','center','center',textColour);
    Screen('Flip',win);
    WaitSecs(2);
    
    % Close the Psychtoolbox window and bring back the cursor and keyboard
    Screen('CloseAll');
    ListenChar();
     
    % Close the DataPixx2
    if useDatapixx
        Datapixx('Close');
    end
    
    
    % Compute and display payout
    disp(['Mean points: ' num2str(mean(participantData(:,end)))]);
    disp(['Total payout: ' num2str((mean(participantData(:,end))/100) * 5,'%0.2f')]);
    
catch e
    
    % Save important variables
    save(mfilename, 'banditColours', 'nBandits', 'meanPayouts', 'actualPayouts','blockOrder', 'participantChoices','participantRTs','participantData');
    
    % Close the Psychtoolbox window and bring back the cursor and keyboard
    Screen('CloseAll');
    ListenChar();
     
    % Close the DataPixx2
    if useDatapixx
        Datapixx('Close');
    end
   
    % Compute and display payout
    disp(['Mean points: ' num2str(mean(participantData(:,end)))]);
    disp(['Total payout: ' num2str((mean(participantData(:,end))/100) * 5,'%0.2f')]);
    
    rethrow(e);
end