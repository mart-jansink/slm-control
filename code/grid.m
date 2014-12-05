function grid

    global SLM ROI GRID

    % generate a grid to combine several pixels of the SLM
    GRID.size = [ 3 3 ];
    GRID.steps = ROI.size ./ GRID.size;

    GRID.X = ( 1 : GRID.steps( 1 ) ) * GRID.size( 2 ) - GRID.size( 2 ) / 2 + .5 + ROI.offset( 2 ) - SLM.width / 2;
    GRID.Y = ( 1 : GRID.steps( 2 ) ) * GRID.size( 1 ) - GRID.size( 1 ) / 2 + .5 + ROI.offset( 1 ) - SLM.height / 2;

    GRID.indices.pattern = cell( [ GRID.steps 2 ] );
    GRID.indices.measurement = cell( [ GRID.steps 2 ] );

    function pattern = buildPattern( grays, method )
        if isfield( SLM, 'calibration' )
            zeroValue = mean( SLM.calibration.pattern.minimum(:) );
        else
            zeroValue = 0;
        end
        
        if ( ( nargin == 1 ) || strcmpi( method, 'repeat' ) )
            pattern = zeros( SLM.size ) + zeroValue;
            
            for bh = 1 : GRID.steps( 2 )
                for bv = 1 : GRID.steps( 1 )
                    pattern( ...
                        ROI.offset( 1 ) + ( bv - 1 ) * GRID.size( 1 ) + ( 1 : GRID.size( 1 ) ) ...
                      , ROI.offset( 2 ) + ( bh - 1 ) * GRID.size( 2 ) + ( 1 : GRID.size( 2 ) ) ...
                    ) = grays( bv, bh );
                end
            end
        else
            pattern = double( ...
                interp2( GRID.X, GRID.Y, grays, SLM.X, SLM.Y, method, zeroValue ) ...
            );
        end
    end
    GRID.buildPattern = @buildPattern;

    function results = discretizeTo( image, method, overflow )
        if ( nargin < 2 )
            method = @sum;
        end
        
        
        center = ROI.offset;
        if all( size( image ) == ROI.size )
            center = [ 0 0 ];
            overflow = 0;
        elseif all( size( image ) == SLM.size )
            center = ROI.offset;
        end

        results = zeros( GRID.steps );
        for bh = 1 : GRID.steps( 2 )
            for bv = 1 : GRID.steps( 1 )
                results( bv, bh ) = method( method( ...
                    image( ...
                        center( 1 ) + ( bv - 1 ) * GRID.size( 1 ) + ( ( 1 - overflow ) : ( GRID.size( 1 ) + overflow ) ) ...
                      , center( 2 ) + ( bh - 1 ) * GRID.size( 2 ) + ( ( 1 - overflow ) : ( GRID.size( 2 ) + overflow ) ) ...
                    ) ...
                ) );
            end
        end
    end
    GRID.discretizeTo = @discretizeTo;      

end