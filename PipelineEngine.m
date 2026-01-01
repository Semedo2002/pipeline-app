classdef PipelineEngine < handle
    
    properties
        Fluid          
        Pipe           
        Geometry       
        Constraints     
        TargetFlow     
        PumpCurve     
        Results         
        PumpsAdded      
    end
    
    methods
        function obj = PipelineEngine()
            obj.Geometry = table([], [], [], 'VariableNames', {'Length', 'ElevationChange', 'MinorLossK'});
        end
        
        %% ---config---
        
        function setFluid(obj, type)
            switch lower(type)
                case 'petrol'
                    obj.Fluid.Name = 'Petrol (Gasoline)';
                    obj.Fluid.Rho = 737;    
                    obj.Fluid.Mu  = 0.0006;
                    obj.Fluid.VapP = 60000;
                case 'diesel'
                    obj.Fluid.Name = 'Diesel Fuel';
                    obj.Fluid.Rho = 850;
                    obj.Fluid.Mu  = 0.0025;
                    obj.Fluid.VapP = 1000;
                case 'crude_light'
                    obj.Fluid.Name = 'Light Crude Oil';
                    obj.Fluid.Rho = 870;
                    obj.Fluid.Mu  = 0.0100;
                    obj.Fluid.VapP = 40000;
                otherwise
                    error('Unknown Fluid Type. Use: petrol, diesel, or crude_light');
            end
        end
        
        function setPipeStandard(obj, nominal_inch, schedule)
            obj.Pipe.Roughness = 0.000045;
            in2m = 0.0254;
            
            switch nominal_inch
                case 6
                    od = 6.625 * in2m;
                    thk = (schedule == 40) * 0.28 * in2m + (schedule == 80) * 0.432 * in2m;
                case 10
                    od = 10.75 * in2m;
                    thk = 0.365 * in2m;
                case 20
                    od = 20.00 * in2m;
                    thk = 0.500 * in2m;
                otherwise
                    od = nominal_inch * in2m;
                    thk = 0.02 * od; 
            end
            
            if thk == 0; thk = 0.01; end
            
            obj.Pipe.OD = od;
            obj.Pipe.Wall = thk;
            obj.Pipe.ID = od - 2*thk;
            obj.Pipe.Area = pi * (obj.Pipe.ID/2)^2;
        end
        
        function addSegment(obj, length_m, elev_change_m, num_90_bends)
            K_total = num_90_bends * 0.3;
            newRow = {length_m, elev_change_m, K_total};
            obj.Geometry = [obj.Geometry; newRow];
        end
        
        %% ---solver---
        
        function runSimulation(obj)
            Q_vol = obj.TargetFlow / obj.Fluid.Rho;
            velocity = Q_vol / obj.Pipe.Area;
            Re = (obj.Fluid.Rho * velocity * obj.Pipe.ID) / obj.Fluid.Mu;
            
            % colebrook fric
            f = obj.solveColebrook(Re, obj.Pipe.Roughness, obj.Pipe.ID);
            
            dx = 20;
            dist = 0;
            elev = 0;
            
            P_min_req = obj.Constraints.MinPressure; 
            head_min_req = P_min_req / (obj.Fluid.Rho * 9.81);
            
            % intialization
            current_head = 500;
            dist_vec = []; elev_vec = []; head_vec = []; pres_vec = [];
            pump_locs = [];
            
            g = 9.81;
            
            % forward algo
            for i = 1:height(obj.Geometry)
                L = obj.Geometry.Length(i);
                dZ = obj.Geometry.ElevationChange(i);
                K = obj.Geometry.MinorLossK(i);
                
                slope = dZ / L;
                h_minor_per_m = (K * velocity^2 / (2*g)) / L;
                h_major_per_m = f * (1/obj.Pipe.ID) * (velocity^2 / (2*g));
                total_loss_m = h_major_per_m + h_minor_per_m;
                
                steps = ceil(L/dx);
                step_len = L/steps;
                
                for s = 1:steps
                    dist = dist + step_len;
                    elev = elev + (slope * step_len);
                    
                    current_head = current_head - (total_loss_m * step_len);
                    P_head = current_head - elev;
                    
                    % --- optimization ---
                    if P_head < head_min_req
                        boost = 150; 
                        current_head = current_head + boost;
                        pump_locs = [pump_locs; dist, elev, boost];
                    end
                    
                    dist_vec(end+1) = dist;
                    elev_vec(end+1) = elev;
                    head_vec(end+1) = current_head;
                    pres_vec(end+1) = (current_head - elev) * obj.Fluid.Rho * g;
                end
            end
            obj.Results = table(dist_vec', elev_vec', head_vec', pres_vec', ...
                'VariableNames', {'Distance', 'Elevation', 'HGL', 'Pressure'});
            
            % --- empty puimp?---
            if isempty(pump_locs)
                obj.PumpsAdded = table([], [], [], 'VariableNames', {'Distance', 'Elevation', 'HeadAdded'});
            else
                obj.PumpsAdded = array2table(pump_locs, 'VariableNames', {'Distance', 'Elevation', 'HeadAdded'});
            end
            
            fprintf('Simulation Complete. %d Pumps Installed automatically.\n', height(obj.PumpsAdded));
        end
        
    end
    
    methods (Access = private)
        function f = solveColebrook(~, Re, epsilon, D)
            % raphson
            if Re < 2300; f = 64/Re; return; end
            f = 0.02;
            for k=1:20
                term = -2 * log10( (epsilon/D)/3.7 + 2.51/(Re * sqrt(f)) );
                res = 1/sqrt(f) - term;
                if abs(res)<1e-6; break; end
                df = -0.5*f^(-1.5);
                f = f - res/df;
            end
        end
    end
end
