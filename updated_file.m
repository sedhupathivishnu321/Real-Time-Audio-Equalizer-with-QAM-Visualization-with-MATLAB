function audioEqualizerApp()
    % Set up global variables
    global audioData sampleRate qamSignal M dynamicAxHandle staticAx2DHandle staticAx3DHandle player isPaused;
    M = 16; % Initial default QAM level
    isPaused = false;

    % Create the main figure
    fig = figure('Position', [100, 100, 800, 600]);

    % Add load audio button
    uicontrol('Style', 'pushbutton', 'String', 'Load Audio', ...
              'Position', [50, 800, 100, 30], ...
              'Callback', @(src, event) loadAudio());

    % Add QAM conversion button
    uicontrol('Style', 'pushbutton', 'String', 'Convert to QAM', ...
              'Position', [200, 800, 100, 30], ...
              'Callback', @(src, event) convertToQAM());

    % Add play button for audio with QAM visualization
    uicontrol('Style', 'pushbutton', 'String', 'Play with QAM', ...
              'Position', [350, 800, 100, 30], ...
              'Callback', @(src, event) playAudioWithQAM());
    
    % Add pause button
    uicontrol('Style', 'pushbutton', 'String', 'Pause/Resume', ...
              'Position', [500, 800, 100, 30], ...
              'Callback', @(src, event) togglePause());

    % Add reset button
    uicontrol('Style', 'pushbutton', 'String', 'Reset', ...
              'Position', [650, 800, 100, 30], ...
              'Callback', @(src, event) resetPlayback());

    % Create axes for real-time waveform (left side)
    dynamicAx = axes('Position', [0.1, 0.1, 0.4, 0.6], 'Parent', fig);
    xlabel(dynamicAx, 'Time');
    ylabel(dynamicAx, 'Amplitude');
    title(dynamicAx, 'Real-time QAM Signal Waveform');
    
    % Create axes for 2D QAM constellation (right side)
    staticAx2D = axes('Position', [0.55, 0.4, 0.4, 0.5], 'Parent', fig);
    xlabel(staticAx2D, 'In-phase (I)');
    ylabel(staticAx2D, 'Quadrature (Q)');
    title(staticAx2D, '2D QAM Constellation');

    % Create axes for 3D QAM constellation (right side, below 2D plot)
    staticAx3D = axes('Position', [0.55, 0.1, 0.4, 0.2], 'Parent', fig);
    xlabel(staticAx3D, 'In-phase (I)');
    ylabel(staticAx3D, 'Quadrature (Q)');
    zlabel(staticAx3D, 'Time');
    title(staticAx3D, '3D QAM Constellation');

    % Store the axes in global variables
    dynamicAxHandle = dynamicAx;
    staticAx2DHandle = staticAx2D;
    staticAx3DHandle = staticAx3D;
end

function loadAudio()
    % Load an audio file
    global audioData sampleRate;
    [fileName, pathName] = uigetfile('*.mp3', 'Select an audio file');
    if isequal(fileName, 0)
        disp('Audio file loading canceled');
    else
        [audioData, sampleRate] = audioread(fullfile(pathName, fileName));
        disp('Audio file loaded successfully');
    end
end

function convertToQAM()
    % Convert loaded audio to QAM signal
    global audioData qamSignal M;
    if isempty(audioData)
        errordlg('Please load an audio file first.');
        return;
    end

    % Normalize and scale audio signal to integer range [0, M-1]
    normalizedData = audioData / max(abs(audioData)); % Normalize to [-1, 1]
    scaledData = round((normalizedData + 1) * ((M - 1) / 2)); % Scale to [0, M-1]
    
    % Apply QAM modulation
    qamSignal = qammod(scaledData, M);
    disp('Audio signal converted to QAM');
end

function playAudioWithQAM()
    % Play audio with real-time QAM visualization
    global audioData sampleRate qamSignal M dynamicAxHandle staticAx2DHandle staticAx3DHandle player isPaused;

    if isempty(audioData) || isempty(qamSignal)
        errordlg('Please load and convert the audio to QAM first.');
        return;
    end

    % Set up the audio player
    player = audioplayer(audioData, sampleRate);
    play(player);

    % Generate QAM constellation points
    rows = floor(sqrt(M));
    cols = ceil(M / rows);
    [I, Q] = meshgrid((-cols+1):2:(cols-1), (-rows+1):2:(rows-1));
    constellation = I(:) + 1j * Q(:);
    constellation = constellation(1:M); % Take only the first M points

    % Create time vector for plotting
    frameSize = 1024; % Define frame size for real-time processing
    numFrames = floor(length(qamSignal) / frameSize);

    % Real-time QAM visualization while audio plays
    for frameIdx = 1:numFrames
        if ~isplaying(player)
            break;
        end
        if isPaused
            pause(0.1);
            continue;
        end

        % Extract frame data
        frameStart = (frameIdx - 1) * frameSize + 1;
        frameEnd = frameIdx * frameSize;
        frameData = qamSignal(frameStart:frameEnd);
        t = linspace((frameIdx - 1) * frameSize / sampleRate, frameIdx * frameSize / sampleRate, frameSize);

        % Ensure handles are valid before using cla
        if ishandle(dynamicAxHandle)
            % Update waveform plot
            cla(dynamicAxHandle);
            plot(dynamicAxHandle, t, real(frameData), 'b');
            hold(dynamicAxHandle, 'on');
            plot(dynamicAxHandle, t, imag(frameData), 'r');
            grid(dynamicAxHandle, 'on');
            xlim(dynamicAxHandle, [min(t), max(t)]);
            ylim(dynamicAxHandle, [-max(abs(qamSignal)), max(abs(qamSignal))]);
            hold(dynamicAxHandle, 'off');
            title(dynamicAxHandle, 'Real-time QAM Signal Waveform');
            xlabel(dynamicAxHandle, 'Time');
            ylabel(dynamicAxHandle, 'Amplitude');
        end
        
        if ishandle(staticAx2DHandle)
            % Update 2D constellation
            cla(staticAx2DHandle);
            scatter(staticAx2DHandle, real(constellation), imag(constellation), 'filled');
            hold(staticAx2DHandle, 'on');
            scatter(staticAx2DHandle, real(frameData), imag(frameData), 'r');
            grid(staticAx2DHandle, 'on');
            axis(staticAx2DHandle, 'equal');
            xlim(staticAx2DHandle, [-cols, cols]);
            ylim(staticAx2DHandle, [-rows, rows]);
            hold(staticAx2DHandle, 'off');
            title(staticAx2DHandle, '2D QAM Constellation with Real-time Data');
            xlabel(staticAx2DHandle, 'In-phase (I)');
            ylabel(staticAx2DHandle, 'Quadrature (Q)');
        end

        if ishandle(staticAx3DHandle)
            % Update 3D constellation
            cla(staticAx3DHandle);
            plot3(staticAx3DHandle, real(frameData), imag(frameData), t, 'r');
            hold(staticAx3DHandle, 'on');
            scatter3(staticAx3DHandle, real(constellation), imag(constellation), zeros(size(constellation)), 'filled');
            grid(staticAx3DHandle, 'on');
            xlim(staticAx3DHandle, [-cols, cols]);
            ylim(staticAx3DHandle, [-rows, rows]);
            zlim(staticAx3DHandle, [0, max(t)]);
            hold(staticAx3DHandle, 'off');
            title(staticAx3DHandle, '3D QAM Constellation with Real-time Data');
            xlabel(staticAx3DHandle, 'In-phase (I)');
            ylabel(staticAx3DHandle, 'Quadrature (Q)');
            zlabel(staticAx3DHandle, 'Time');
        end

        % Small pause for real-time update
        pause(frameSize / sampleRate);
    end
end

function togglePause()
    % Toggle pause and resume playback
    global isPaused player;
    isPaused = ~isPaused;
    if isPaused
        pause(player);
    else
        resume(player);
    end
end

function resetPlayback()
    % Reset playback and clear visualizations
    global player dynamicAxHandle staticAx2DHandle staticAx3DHandle isPaused;
    if ~isempty(player) && isplaying(player)
        stop(player);
    end
    isPaused = false;

    % Clear all axes
    if ishandle(dynamicAxHandle)
        cla(dynamicAxHandle);
    end
    if ishandle(staticAx2DHandle)
        cla(staticAx2DHandle);
    end
    if ishandle(staticAx3DHandle)
        cla(staticAx3DHandle);
    end
end
