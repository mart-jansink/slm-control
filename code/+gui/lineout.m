function lineout

    global FIG ROI AX LINEOUT RESULT CONFIG

    function c = coordinates
        c = round( get( AX.image, 'currentPoint' ) );
        if ROI.hit( c( 1, 1 ), c( 1, 2 ) )
            c = c( 1, 1:2 );
        else
            c = false;
        end
    end

    dragging = false;
    function down( varargin )
        dragging = true;
    end

    function move( varargin )
        if dragging
            c = coordinates();
            if c
                display( c );
            end
        end
    end

    function up( varargin )
        dragging = false;
        c = coordinates();
        if c
            display( c )
        end
    end

    set( FIG.main ...
      , 'WindowButtonDownFcn',  @down ...
      , 'windowButtonMotionFcn', @move ...
      , 'WindowButtonUpFcn',  @up ...
    );

    coords = round( ROI.size / 2 ); source = '';
    function display( c, s )
        % update the last selected coordinates if new ones are provided
        if ( nargin == 1 )
            coords = c - fliplr( ROI.offset );
        end
        
        if ( nargin == 2 )
            source = s;
        end
        
        if ~isfield( RESULT, source ) || isempty( RESULT.( source ) )
            return
        end 
        
        data = ROI.select( RESULT.( source ) );
        range = [ 0 max( data(:) ) ];
        
        plot( AX.lineplot.x ...
          , 1:ROI.width, data( coords( 2 ), : ), 'g' ...
        );
        set( AX.lineplot.x, 'yLim', range );
        
        plot( AX.lineplot.y ...
          , data( :, coords( 1 ) ), 1:ROI.height, 'r' ...
        );
        set( AX.lineplot.y, 'xLim', range );
        
        plot( AX.lineplot.marker ...
          , coords( 1 ) + ROI.offset( 2 ), coords( 2 ) + ROI.offset( 1 ), 'rx' ...
        );
    end
    LINEOUT.display = @display;


end