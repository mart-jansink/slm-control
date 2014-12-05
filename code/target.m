function target
    global TARGET CONFIG ROI CONTROLLER GRID AX SLM

    TARGET.original    = [];
    TARGET.transformed = zeros( ROI.size );
    TARGET.scaled      = zeros( ROI.size );
    TARGET.discretized = zeros( GRID.steps );
    TARGET.mask        = zeros( GRID.steps );
    
    
    function set( target )
        TARGET.original = target;
        
        transform();
        display();
    end
    TARGET.set = @set;
    
    function transform
        if isempty( TARGET.original )
            return
        end
        
        % create a shortcut and define the SRT matrices
        t = CONFIG.transform;
        translate = [ 1         0         0
                      0         1         0 
                      t.shift.x t.shift.y 1 ];
        scale     = [ t.scale.x 0         0
                      0         t.scale.y 0
                      0         0         1 ];
        rotate    = [ cosd( t.angle ) -sind( t.angle ) 0
                      sind( t.angle )  cosd( t.angle ) 0
                      0                0               1 ];
                  
        % let the transforms work around the center of the image
        [ h, w ] = size( TARGET.original );
        
        origin = [ 0   0   0
                   0   0   0
                   w/2 h/2 0 ];
        
        transformation = affine2d( ...
            ( eye( 3 ) - origin ) ...
          * scale ...
          * rotate ...
          * ( eye( 3 ) + origin ) ...
          * translate ...
        );
    
        ref = imref2d( ROI.size );
        ref.XWorldLimits = ref.XWorldLimits + w/2 - ROI.width / 2;
        ref.YWorldLimits = ref.YWorldLimits + h/2 - ROI.height / 2;
        
        TARGET.transformed = imwarp( ...
            TARGET.original ...
          , transformation ...
          , 'outputView', ref ...
          , 'fillValues', TARGET.original( 1, 1, : ) ...
        );
    
        display();
        CONTROLLER.reset();
    end
    TARGET.transform = @transform;
    
    
    function invert( varargin )
        set( max( TARGET.original(:) ) - TARGET.original );
    end
    TARGET.invert = @invert;

    
    function display
        imshow( TARGET.transformed, [], 'parent', AX.target );
        drawnow;
    end
    TARGET.display = @display;

end