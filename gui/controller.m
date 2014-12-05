function controller
    
    global CONTROLLER SLM TARGET GRID CAMERA CONFIG RESULT
    
    CONTROLLER.iteration = 0;
    
    present = []; history = [];
    
    
    function reset( varargin )
        CONTROLLER.iteration = 0;
        
        CONFIG.maxIterations = 5;
        
        TARGET.discretized = GRID.discretizeTo( TARGET.transformed, @mean, 0 );
        
        % determine the maximum intensity possible
        index = ( TARGET.discretized == max( TARGET.discretized(:) ) );
        maximumIntensity = min( SLM.calibration.intensity.maximum( index ) ) * .75;
        
        % and scale the target accordingly
        TARGET.scaled = double( TARGET.discretized ) * maximumIntensity;
        
        % define a mask for the area to control
        TARGET.mask = ( TARGET.scaled > 1 );
        
        % and layout it initial 'current' results
        present.result     = zeros( GRID.steps );
        present.error      = zeros( GRID.steps );
        present.change     = zeros( GRID.steps );
        present.pattern    = zeros( GRID.steps );
        present.quality    = -1;
        present.roughness  = Inf;
        present.peak2rms   = Inf;
        present.gain       = 1 / maximumIntensity * 4;
        
        % finally, determine the starting conditions
        present.pattern = SLM.calibration.pattern.minimum ...
          + SLM.calibration.pattern.difference .* TARGET.scaled ./ SLM.calibration.intensity.maximum;
    
        history = [];
        
        autoIterate();
    end
    CONTROLLER.reset = @reset;

    
    function iterate( varargin )
        CONTROLLER.iteration
        
        history = [ present; history ];

        SLM.update( GRID.buildPattern( present.pattern ) );
        hdr = CAMERA.hdr( 6 );
        present.result = GRID.discretizeTo( hdr, @mean, 1 );

        RESULT.display( 'hdr' );

        % analyze the result
        present.error     = double( TARGET.scaled - present.result );
        present.quality   = 1 / rms( present.error( TARGET.mask ) );
        present.roughness = rms( present.result( TARGET.mask ) - mean( present.result( TARGET.mask ) ) );
        present.peak2rms  = peak2rms( present.error( TARGET.mask ) );

        % apply the gain and improve the pattern
        present.change = round( present.error .* present.gain );
        present.pattern(TARGET.mask ) = present.pattern( TARGET.mask ) + present.change( TARGET.mask );

        % minimize the zero area with a simple linear search
%         changes = [ -2 1 ];
%         for c = 1:length( changes )
%             pattern = current.pattern;
%              pattern( ~mask ) = current.pattern( ~mask ) + changes( c );
%              fullscreen( buildPattern( pattern ), SLM.handle );
%              pause( .2 );
%              hdr = captureHDR( 3 );
%              imshow( hdr, [ 0 maximumIntensity * 1.5 ] );
%              result( :, :, c ) = discretizeToGrid( hdr, @mean, 1 );
%           end

%          [ ~, optimumIndices ] = min( result, [], 3 );
%          current.pattern( ~mask ) = current.pattern( ~mask ) + changes( optimumIndices( ~mask ) ).';

        present
        

        CONTROLLER.iteration = CONTROLLER.iteration + 1;
    end
    CONTROLLER.iterate = @iterate;
    
    
    function finalize
        SLM.update( GRID.buildPattern( present.pattern ) );
        hdr = CAMERA.hdr( 20 );

        RESULT.display( 'hdr' );
    end

    isIterating = false;
    function autoIterate( varargin )
        if CONTROLLER.iteration > CONFIG.maxIterations
            CONTROLLER.iteration = 0;
        end
        
        if isIterating
            return
        end
        
        isIterating = true;
        while CONFIG.autoIterate && ( CONTROLLER.iteration < CONFIG.maxIterations )
            iterate();
            
            if length( history ) > 3
                if all( history( 4 ).quality >= [ history( 1:3 ).quality ] )
                    [ ~, index ] = max( [ history.quality ] )
                    present = history( index );
                    finalize();
                    break;
                end
            end
        end
        isIterating = false;
    end
    CONTROLLER.autoIterate = @autoIterate;

end