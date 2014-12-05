function slm

    global SLM GRID ROI CAMERA CONFIG AX PROGRESS RESULT

    % load the gain, bias and any previous calibration
    SLM = load( 'slm.mat' );
    
    SLM.width = 800; SLM.height = 600;
    SLM.size = [ SLM.height SLM.width ];

     % define a pixel grid based on the width and height
    [ SLM.X, SLM.Y ] = meshgrid( ...
        ( ( 1 : SLM.width ) - SLM.width / 2 ) ...
      , ( ( 1 : SLM.height ) - SLM.height / 2 ) ...
    );
    % and calculate the distance to the center for each pixel
    SLM.R = sqrt( SLM.X.^2 + SLM.Y.^2 );
    
    % load the gain and bias
    % to calculate the repetition period of the SLM in graylevels
    SLM.period = round( ( SLM.transfer.bias + SLM.transfer.gain * CONFIG.wavelength ) * 2 * pi );
    
    % start with a black screen
    SLM.pattern = zeros( SLM.size, 'uint8' );
        
    % then create an undecorated window on the second monitor
    ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment;
    gds = ge.getScreenDevices;
    gdc = gds( min( length( gds ), 2 ) ).getDefaultConfiguration;

    frame = javax.swing.JFrame( gdc );
    frame.setUndecorated( true );

    icon = javax.swing.ImageIcon( im2java( SLM.pattern ) );
    label = javax.swing.JLabel( icon );
    frame.getContentPane.add( label );

    frame.pack;
    frame.show;

    % and allow access to it from the handle
    SLM.handle = struct( 'frame', frame, 'icon', icon );
    
    
    function update( pattern )
        if ( nargin == 1 )
            SLM.pattern = uint8( pattern );
        end
        
        image = SLM.pattern;
        if CONFIG.blankSLM
            image = false( SLM.size );
        end
        
        % show the pattern on the second screen
        SLM.handle.icon.setImage( im2java( image ) );
        SLM.handle.frame.repaint;
        
        % and in the preview window
        imshow( SLM.pattern, [ 0 255 ], 'parent', AX.preview );
        drawnow;
        
        % with two frameupdates before proceeding
        pause( 2 / 60 );
    end
    SLM.update = @update;
    
    
    function close
        try SLM.handle.frame.dispose; catch, end
    end
    SLM.close = @close;
    
    
    function sweep( varargin )
        stop( CAMERA.timer );
        
        grays = 0 : 1 : 255;
        results = zeros( [ SLM.size length( grays ) ], 'single' );
        
        % for all gray levels to test
        for g = 1 : length( grays );
            % show progress
            PROGRESS.update( ...
                g / length( grays ) ...
              , 'Progress of SLM sweep'...
              , sprintf( 'sweeping graylevel %d out of %d..', g, length( grays ) ) ...
            );
        
            pattern = zeros( SLM.size, 'uint8' ) + grays( g );

            % display it on the SLM
            SLM.update( pattern );

            % capture the result
            hdr = CAMERA.hdr( 6 );

            % display it to show progress
            RESULT.display( 'hdr' );

            % analyze the captured image
            results( :, :, g ) = hdr;
        end
        
        start( CAMERA.timer );
        save( 'sweep.mat', 'results' );
    end
    SLM.sweep = @sweep;
    
    
    function calibrate( varargin )
        stop( CAMERA.timer );
        
        % optimize in two steps: first a coarse one then the second step 
        % with one graylevel difference between each test
        coarseTestGrays =  36 : 4 : 96;
        fineTestGrays = -4 : 1 : 4;
        
        % for each graylevel a HDR image is taken with 6 exposure steps,
        % the final results are measured with two extra images taken over
        % 20 exposure steps, so define a smooth progress function
        totalSteps = 6 * length( [ coarseTestGrays fineTestGrays ] ) + 2 * 20;
        currentStep = 0; currentMessage = '';
        function progressCallback( message )
            if nargin == 1
                currentMessage = message;
            else
                currentStep = currentStep + 1;
            end
            
            PROGRESS.update( ...
                currentStep / totalSteps ...
              , 'Progress of SLM calibration'...
              , currentMessage ...
            );
        end
        
        function testResults = testGrayLevels( grays, startingTestPattern, exposureSteps, test )
            testResults = zeros( [ GRID.steps, length( grays ) ] );
            testPattern = startingTestPattern;
            
            % for all gray levels to test
            for g = 1 : length( grays );
                % show progress
                progressCallback( sprintf( 'testing %s graylevel %d out of %d..', test, g, length( grays ) ) );
                
                % modify the starting test pattern
                testPattern( ROI.index ) = startingTestPattern( ROI.index ) + grays( g );

                % display it on the SLM
                SLM.update( testPattern );
                
                % capture the result
                hdr = CAMERA.hdr( exposureSteps, @progressCallback );

                % display it to show progress
                RESULT.display( 'hdr' );

                % analyze the captured image
                testResults( :, :, g ) = GRID.discretizeTo( hdr, @sum, 1 );
            end
        end
        
        % execute the coarse test
        coarseResults = testGrayLevels( coarseTestGrays, zeros( SLM.size, 'uint8' ), 6, 'coarse' );
        % in which both the minimum and maximum intensity are 
        % determined simultaneously
        [ ~, index ] = min( coarseResults, [], 3 );
        minimumGrayLevels = coarseTestGrays( index );

        % then, apply the fine tests around the previously found results
        % for the minimum intensity
        fineResults = testGrayLevels( fineTestGrays, GRID.buildPattern( minimumGrayLevels ), 6, 'fine minimum' );
        [ ~, index ] = min( fineResults, [], 3 );
        minimumGrayLevels = max( minimumGrayLevels + fineTestGrays( index ), 0 );

        % calculate the maximum gray levels from the previous result
        maximumGrayLevels = minimumGrayLevels + round( SLM.period / 2 );
        
        % finally, generate the minimum and maximum patterns, test them and
        % get the results and store everything on the SLM object:
        progressCallback( 'measuring minimum intensity..' );
        SLM.calibration.pattern.minimum  = minimumGrayLevels;
        SLM.update( GRID.buildPattern( SLM.calibration.pattern.minimum ) );
        minimumResult = CAMERA.hdr( 20, @progressCallback );
        SLM.calibration.intensity.minimum = GRID.discretizeTo( minimumResult, @mean, 0 );
        
        progressCallback( 'measuring maximum intensity..' );
        SLM.calibration.pattern.maximum = maximumGrayLevels;
        SLM.update( GRID.buildPattern( SLM.calibration.pattern.maximum ) );
        maximumResult = CAMERA.hdr( 20, @progressCallback );
        SLM.calibration.intensity.maximum = GRID.discretizeTo( maximumResult, @mean, 0 );
        
        SLM.calibration.pattern.difference = ...
            SLM.calibration.pattern.maximum - SLM.calibration.pattern.minimum;
            
        figure( ...
            'name', 'SLM calibration results' ...
          , 'numberTitle', 'off' ...
        );
        imshow( [ minimumResult, maximumResult ], [] );
            
        save( 'slm.mat', '-append', '-struct', 'SLM', 'calibration' );
        
        start( CAMERA.timer );
    end
    SLM.calibrate = @calibrate;
end