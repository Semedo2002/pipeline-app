function PipelineApp()
    % PIPELINEAPP 
    
    clc; clear; close all;
    
    fprintf('==========================================================\n');
    fprintf('      PETROL PIPELINE DESIGN SUITE - v3.0    \n');
    fprintf('==========================================================\n');
    
    % Init Engine
    Engine = PipelineEngine();
    
    %% fluid
    valid = false;
    while ~valid
        choice = input('\n[1] Select Fluid Service:\n 1. Petrol (Gasoline)\n 2. Diesel\n 3. Light Crude\n > ', 's');
        try
            if choice == '1'; Engine.setFluid('petrol'); valid=true;
            elseif choice == '2'; Engine.setFluid('diesel'); valid=true;
            elseif choice == '3'; Engine.setFluid('crude_light'); valid=true;
            end
        catch
            fprintf('Error setting fluid. Try again.\n');
        end
    end
    fprintf('>> Fluid Set: %s\n', Engine.Fluid.Name);
    
    %% OTs
    fprintf('\n[2] Operation Targets:\n');
    m_flow = input('   Enter Target Mass Flow Rate (kg/s) [e.g., 250]: ');
    Engine.TargetFlow = m_flow;
    Engine.Constraints.MinPressure = 1.5e5; 
    Engine.Constraints.MaxPressure = 60e5;  
    
    %% pipe
    fprintf('\n[3] Pipe Specification (ASME B36.10M):\n');
    p_size = input('   Nominal Pipe Size (Inches) [6, 10, 20]: ');
    Engine.setPipeStandard(p_size, 40); 
    fprintf('   >> Selected OD: %.4f m, ID: %.4f m\n', Engine.Pipe.OD, Engine.Pipe.ID);
    
    %% geom
    fprintf('\n[4] Define Pipeline Geometry:\n');
    fprintf('   We will add segments sequentially.\n');
    
    more_segments = true;
    seg_count = 1;
    
    %loop
    while more_segments
        fprintf('\n   --- Segment %d ---\n', seg_count);
        L = input('   Length (m): ');
        dZ = input('   Elevation Change (+Up/-Down) (m): ');
        bends = input('   Number of 90-degree bends/fittings: ');
        
        Engine.addSegment(L, dZ, bends);
        
        check = input('   Add another segment? (y/n): ', 's');
        if lower(check) == 'n'; more_segments = false; end
        seg_count = seg_count + 1;
    end
    
    %% solution
    fprintf('\n[5] Running Computational Fluid Dynamics Solver...\n');
    pause(1); % Simulation feel
    Engine.runSimulation();
    
    % --- Plots ---
    Results = Engine.Results;
    Pumps = Engine.PumpsAdded;
    
    figure('Color', 'w', 'Name', 'Professional Design Report', 'Units','normalized','Position',[0.1 0.1 0.8 0.8]);
    
    % hydrulic gradient
    subplot(2,1,1); hold on; grid on;
    area(Results.Distance/1000, Results.Elevation, 'FaceColor', [0.8 0.8 0.8], 'DisplayName', 'Terrain');
    plot(Results.Distance/1000, Results.HGL, 'b-', 'LineWidth', 2, 'DisplayName', 'Hydraulic Grade Line');
    
    if ~isempty(Pumps)
        plot(Pumps.Distance/1000, Pumps.Elevation, 'rp', 'MarkerSize', 10, 'MarkerFaceColor','r', 'DisplayName', 'Pump Station');
        % Label pumps if count is low
        if height(Pumps) < 15
            text(Pumps.Distance/1000, Pumps.Elevation+20, string(1:height(Pumps))', 'Color','r','FontWeight','bold');
        else
            text(Results.Distance(end)/1000, max(Results.HGL), sprintf(' TOTAL PUMPS: %d', height(Pumps)), 'Color','r');
        end
    end
    
    ylabel('Head / Elevation (m)');
    title(['Hydraulic Profile: ', Engine.Fluid.Name]);
    legend('show', 'Location', 'best');
    
    % Subplot 2: Pressure
    subplot(2,1,2); hold on; grid on;
    pres_bar = Results.Pressure / 1e5;
    plot(Results.Distance/1000, pres_bar, 'r-', 'LineWidth', 1.5);
    yline(Engine.Constraints.MinPressure/1e5, 'k--', 'Min Safe Pressure');
    xlabel('Distance (km)');
    ylabel('Pressure (bar)');
    title('Internal Pressure Profile');
    
    fprintf('\nDONE. Graphical Report Generated.\n');
