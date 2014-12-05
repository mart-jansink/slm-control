function camera

    global CAMERA UTIL SLM ROI RESULT CONFIG GRID UI
    
    % load any previous alignment for the uc480 camera
    CAMERA = load( 'camera.mat' );
    
    CAMERA.handle = [];
    CAMERA.exposureRange = calculateExposureRange( 50 );
    
    CAMERA.timer = timer( ...
        'StartDelay', 1 ...
      , 'Period', 1 ...
      , 'ExecutionMode', 'fixedRate' ...
      , 'TimerFcn', @display...
    );
    
    function success = connect()
        success = false;
        try
            % open the connection to the camera for its first use
            import mmcorej.*;
            CAMERA.handle = CMMCore;
            CAMERA.handle.loadSystemConfiguration ( './dcc1545m.cfg' );

            % and get some info from the device
            CAMERA.imageSize = [ CAMERA.handle.getImageWidth, CAMERA.handle.getImageHeight ];
            if ( CAMERA.handle.getBytesPerPixel == 2 )
                CAMERA.pixelType = 'uint16';
            else
                CAMERA.pixelType = 'uint8';
            end

            % update the exposure with the stored value
            setExposure( 1 );
            
            % start the capturing
            start( CAMERA.timer );

            success = true;
        catch err
            warning( getReport( err, 'basic' ) );
        end
    end
    CAMERA.connect = @connect;
    
    
    function success = disconnect()
        success = true;
        if ~isempty( CAMERA.handle )
            success = false;
            % close the connection to the camera
            try 
                stop( CAMERA.timer );
                
                CAMERA.handle.unloadAllDevices();
                CAMERA.handle = [];
                success = true;
            catch err
                warning( getReport( err, 'basic' ) );
            end
        end
    end
    CAMERA.disconnect = @disconnect;
    
    
    function success = setExposure( exposure )
        success = false;
        if isempty( CAMERA.handle )
            success = connect();
            if ~success, return;  end
        end
        
        CAMERA.handle.setExposure( exposure );
        
        pause( .1 );
        
        CAMERA.exposure = CAMERA.handle.getExposure();
        
        set( UI.camera.exposure.text, 'string', sprintf( '%0.02f', CAMERA.exposure ) );
        set( UI.camera.exposure.slider, 'value', find( CAMERA.exposureRange >= CAMERA.exposure, 1 ) );
        drawnow;
    end
    CAMERA.setExposure = @setExposure;
    
    
    function snapshot = captureSnapshot
        snapshot = [];
        if isempty( CAMERA.handle )
            success = connect();
            if ~success, return;  end
        end
        
        try
            % snap a shot
            CAMERA.handle.snapImage();
            % which is returned as a 1D array of signed integers in 
            % row-major order but must be interpreted as unsigned
            % integers and should be shaped as a 2D array with column-
            % major order for MATLAB
            snapshot =  fliplr( reshape( ...
                typecast( CAMERA.handle.getImage(), CAMERA.pixelType ) ...
              , CAMERA.imageSize ...
            ).' );
        
            RESULT.snapshot = snapshot;

        catch err
            warning( getReport( err, 'basic' ) );
        end
    end
    CAMERA.capture.snapshot = @captureSnapshot;
    
    
    function image = captureImage( varargin )
        image = [];
        if isempty( CAMERA.handle )
            success = connect();
            if ~success, return;  end
        end
        
        snapshot = captureSnapshot();
            
        if ~isempty( snapshot )
            if isempty( CAMERA.alignment )
                % no alignment has been calibrated, so simply crop it
                image = UTIL.clip( snapshot, SLM.height, SLM.width );
            else
                image = imwarp( snapshot, CAMERA.alignment, 'outputView', imref2d( SLM.size ) );
            end
        
            RESULT.image = image;
        end
    end
    CAMERA.capture.image = @captureImage;
    
    
    function display( varargin )
        if strcmp( CONFIG.display, 'image' )
            CAMERA.capture.image();
            RESULT.display();
        end
    end
    CAMERA.display = @display;
    
    
    function align( varargin )
        if isempty( CAMERA.handle )
            success = connect();
            if ~success, return;  end
        end
        
        % pause the camera
        stop( CAMERA.timer );
        
        % define the reference points based on the ROI
        referencePoints = [ 0.50  0.50   % center entire region
                            0.00  0.00   % corners entire region
                            0.00  1.00
                            1.00  1.00
                            1.00  0.00
                            0.50  0.00   % midpoints entire region
                            0.00  0.50
                            0.50  1.00
                            1.00  0.50 
                            0.25  0.25   % center 2nd quadrant
                            0.25  0.00   % midpoints 2nd quadrant
                            0.00  0.25
                            0.25  0.50
                            0.50  0.25
                            0.25  0.75   % center 3rd quadrant
                            0.00  0.75   % midpoints 3rd quadrant
                            0.25  1.00
                            0.50  0.75
                            0.75  0.75   % center 4th quadrant
                            0.75  1.00   % midpoints 4th quadrant
                            1.00  0.75
                            0.75  0.50
                            0.75  0.25   % center 1st quadrant
                            1.00  0.25   % midpoints 1st quadrant
                            0.75  0.00 ];
                        
        referencePoints( :, 1 ) = referencePoints( :, 1 ) * ( ROI.width - 20 ) + ROI.offset( 2 ) + 10;
        referencePoints( :, 2 ) = referencePoints( :, 2 ) * ( ROI.height - 20 ) + ROI.offset( 1 ) + 10;
        
        referencePoints = floor( referencePoints );
                        
        cameraPoints = zeros( size( referencePoints ) );
        
        % create a marker
        alignmentMarker = [ zeros( 20 )         tril( ones( 20 ) )
                            triu( ones( 20 ) )  zeros( 20 )        ];
        
        % define some 'global' variables
        alignmentPattern = []; grayOffset = 0; lastSnapshot = [];
        
        % and some callbacks
        function modifyOffset( ~, data )
            grayOffset = mod( grayOffset + data.VerticalScrollCount + SLM.period, SLM.period );
            
            displayAlignmentPattern();
        end
        
        function displayAlignmentPattern()
            if ~isempty( alignmentPattern ) && ishandle( fig.cameraAlignment )
                % scale and display the alignment pattern
                if isfield( SLM, 'calibration' )
                    grayPattern = alignmentPattern;
                else
                    grayPattern = alignmentPattern * round( SLM.period / 2 ) + grayOffset;
                end
                
                SLM.update( grayPattern );
                
                % and if enough time has passed
                if ( isempty( lastSnapshot ) || toc( lastSnapshot ) > .2 )
                    lastSnapshot = tic;
                   
                    % capture a new snapshot
                    imshow( captureSnapshot(), [ 0 255 ], 'parent', ax.cameraAlignmentImage );
                    drawnow;
                end
            end
        end
        
        function displayLastCoordinate()
            cla( ax.cameraAlignmentCoordinate );
            
            % plot all previously aligned coordinates in blue
            plot( ax.cameraAlignmentCoordinate ...
              , cameraPoints( 1:( point - 1 ), 1 ), cameraPoints( 1: ( point - 1 ), 2 ) ...
              , 'bx', 'markerSize', 10, 'lineWidth', 1 ...
            );
            
            % the current one in green
            plot( ax.cameraAlignmentCoordinate ...
              , cameraPoints( point, 1 ), cameraPoints( point, 2 ) ...
              , 'gx', 'markerSize', 10, 'lineWidth', 2 ...
            );
        
            % if we've got enough points
            if ( point > 5 )
                
                if ( cameraPoints( point, 1 ) == 0 )
                    pointsIndex = 1:( point - 1 );
                else
                    pointsIndex = 1:point;
                end
                
                % calculate a piecewise linear transform
                tform = fitgeotrans( cameraPoints( pointsIndex, : ), referencePoints( pointsIndex, : ), 'pwl' );
                % apply it to the remaining reference points
                predictedCameraPoints = transformPointsInverse( tform, referencePoints( ( point + 1 ) : end, : ) );
                % and plot them in white
                plot( ax.cameraAlignmentCoordinate ...
                  , predictedCameraPoints( :, 1 ), predictedCameraPoints( :, 2 ) ...
                  , 'ro', 'markerSize', 10, 'lineWidth', 1 ...
                );
            
                cameraPoints( ( point + 1 ) : end, : ) = predictedCameraPoints;
            end
        end
        
        function captureMouseInput( varargin )
            coordinates = get( gca, 'currentPoint' );
            cameraPoints( point, : ) = coordinates( 1, [ 1 2 ] );
            
            displayLastCoordinate();
        end
        
        function captureKeyboardInput( ~, data )
            increment = .5;
            if ~isempty( data.Modifier )
                switch data.Modifier{ 1 }
                    case 'shift'
                        increment = 5;

                    case { 'control', 'command' }
                        increment = .1;
                end
            end
            
            switch data.Key
                case 'return'
                    if ( point < length( referencePoints ) )
                        point = point + 1;
                        processAlignmentPattern();
                    else
                        CAMERA.alignment = fitgeotrans( cameraPoints, referencePoints, 'pwl' );
                        save( 'camera.mat', '-append', '-struct', 'CAMERA', 'alignment' );
                        
                        close( fig.cameraAlignment );
        
                        % resume the camera
                        start( CAMERA.timer );
                        
                        return;
                    end
                
                case 'leftarrow'
                    cameraPoints( point, 1 ) = cameraPoints( point, 1 ) - increment;
                    
                case 'rightarrow'
                    cameraPoints( point, 1 ) = cameraPoints( point, 1 ) + increment;
                    
                case 'uparrow'
                    cameraPoints( point, 2 ) = cameraPoints( point, 2 ) - increment;
                    
                case 'downarrow'
                    cameraPoints( point, 2 ) = cameraPoints( point, 2 ) + increment;
            end
            
            displayLastCoordinate();
        end
                        
        % use a dummy snapshot to create a figure
        snapshot = zeros( fliplr( CAMERA.imageSize ) );
        figure( ...
            'name', 'Camera alignment tool' ...
          , 'numberTitle', 'off' ...
        );
        imshow( snapshot ); fig.cameraAlignment = gcf;
        % with two axes, one for the image that also defines the figure size
        ax.cameraAlignmentImage = get( fig.cameraAlignment, 'currentAxes' );
        
        % and one for the coordinate
        ax.cameraAlignmentCoordinate = axes( ...
            'parent', fig.cameraAlignment ...
          , 'color', 'none' ...
          , 'box', 'off' ...
          , 'xLim', [ 0 CAMERA.imageSize( 1 ) ] ...
          , 'xLimMode', 'manual' ...
          , 'yLim', [ 0 CAMERA.imageSize( 2 ) ] ...
          , 'yLimMode', 'manual' ...
          , 'yDir', 'reverse' ...
          , 'position', [ 0 0 1 1 ] ...
          , 'visible', 'off' ...
          , 'drawMode', 'fast' ...
        );
    
        % for some reason, holding this axis is required, otherwise after
        % moving the coordinate one axis is removed from the figure
        hold( ax.cameraAlignmentCoordinate );
        
        % link both axes to allow zooming and panning
        linkaxes( [ ax.cameraAlignmentCoordinate, ax.cameraAlignmentImage ] );
        
        % and modify some of its properties
        set( fig.cameraAlignment ...
          , 'windowScrollWheelFcn', @modifyOffset ...
          , 'windowButtonUpFcn', @captureMouseInput ...
          , 'windowKeyPressFcn', @captureKeyboardInput ...
        );
            
        % and for each of the reference points
        function processAlignmentPattern()
            % place the marker around that location
            alignmentPattern = zeros( SLM.size );
            alignmentPattern( ...
                ( referencePoints( point, 2 ) + ( -19:20 ) ) ...
              , ( referencePoints( point, 1 ) + ( -19:20 ) ) ...
            ) = alignmentMarker;
        
            % use any available previous calibration result
            if isfield( SLM, 'calibration' )
                alignmentPattern = ...
                    GRID.buildPattern( SLM.calibration.pattern.minimum ) .* ( 1 - alignmentPattern ) ...
                  + GRID.buildPattern( SLM.calibration.pattern.maximum ) .* alignmentPattern;
            end
        
            % display the result
            displayAlignmentPattern();
            
            set( fig.cameraAlignment, 'pointer', 'fullcrosshair');
        end
        point = 1;
        processAlignmentPattern();
    end
    CAMERA.align = @align;
    
    
    function varargout = hdr( numberOfExposures, progressCallback )
        if isempty( CAMERA.handle )
            success = connect();
            if ~success, return;  end
        end
        
        % pause the camera when the HDR button is clicked, otherwise it'll
        % already be stopped by the calling function
        if ( nargin == 0 )
            stop( CAMERA.timer );
        end
        
        % store the current exposure
        previousExposure = CAMERA.exposure;
        
        % define all exposure values
        if ( nargin > 0 )
            exposures = calculateExposureRange( numberOfExposures );
        else
            exposures = calculateExposureRange( 20 );
        end
        % preallocate a matrix for the mean image
        hdr = zeros( fliplr( CAMERA.imageSize ), 'single' );
        % and for the counting of non-NaN values
        counts = ones( fliplr( CAMERA.imageSize ) );
        
        % loop over all exposures
        for e = 1 : length( exposures )
            % push them to the camera and store the actual exposure
            setExposure( exposures( e ) );
            
            % and capture an image from the camera while convert the
            % image from uint8 to single to allow NaN values
            snapshot = single( captureSnapshot() );
            
            % replace all saturated pixels with NaN values to ignore
            % them when averaging
            if ( e > 1 )
                % the first image is the least exposed, therefore don't replace any
                % white pixels as we simply don't have any more information on them
                snapshot( snapshot == 255 ) = NaN;
            end

            if ( e < ( length( exposures ) - 1 ) )
                % the last image is the most exposed, therfore don't replace any
                % black pixels as we simply don't have any more information on them
                snapshot( snapshot == 0 ) = NaN;
            end

            % divide the image by its absolute exposure that are
            % linearly related and use the result to update the mean
            % image
            [ hdr, counts ] = UTIL.incrementalMean( hdr, counts, ...
                snapshot ./ CAMERA.exposure ...
            );
        
            % show progress if required
            if nargin == 2
                progressCallback();
            end
        end
        
        RESULT.hdr = imwarp( hdr, CAMERA.alignment, 'outputView', imref2d( SLM.size ) );
        
        if ( nargout == 0 )
            RESULT.display();
        else
            varargout{ 1 } = RESULT.hdr;
        end
        
        % start the camera when the HDR button is clicked, otherwise it'll
        % already be stopped by the calling function
        if ( nargin == 0 )
            start( CAMERA.timer );
        end
        
        setExposure( previousExposure );
    end
    CAMERA.hdr = @hdr;
    

    function range = calculateExposureRange( steps )
        % the minimum value of the exposure which also equals the smallest
        % change between two consecutive exposure steps
        minimumExposure = 0.0668;
        
        % use interp1 to calculate a shape-preserving piecewise cubic
        % interpolation between predefined set points that give a range of
        % exposures between minimumExposure and 100ms
        range = interp1( ...
            [ 0 1/8 1/2 1 ] ...
          , [ minimumExposure 1 10 100 ] ...
          , linspace( 0, 1, steps ) ...
          , 'pchip' ...
        );
    end
end