function main

    close all; clc; warning off backtrace; %clear all;

    % define the globals
    global SLM ROI GRID CAMERA CONTROLLER CONFIG FIG AX MISC UTIL PROGRESS TARGET RESULT LINEOUT UI %#ok<NUSED>

    % run the child functions to fill the globals
    config; util; slm; roi; grid; camera; controller; target; result;
    
    
    % build the interface
    MISC.padding = 20;
    MISC.controls = 60;
    
    FIG.main = figure( ...
        'name', 'SLM control interface' ...
      , 'numberTitle', 'off' ...
      , 'position', [ 250 50 ( SLM.width + ROI.width + 3 * MISC.padding ) ( SLM.height + 2 * MISC.controls + 5 * MISC.padding ) ] ...
      , 'color', [ 238 238 238 ] / 255 ...
      , 'menuBar', 'none' ...
      , 'toolBar', 'none' ...
      , 'resize', 'off' ...
      , 'deleteFcn', @closeFigure ...
    );

    function closeFigure( varargin )
        % signal the iteration to stop
%         isClosing = true;
        
        % save the configuration
%         save( configFile, 'config' );
        
        % close the SLM display on the second screen
        SLM.close();
        
        CAMERA.disconnect();
         
        
        % and delete all figures
        structfun( @delete, FIG );
    end

    gui.ax; gui.camera; gui.slm; gui.io; gui.progress; gui.target; gui.controller; gui.lineout; gui.memory;
    
    
%     SLM = rmfield( SLM, 'calibration' );

    RESULT.display();
end