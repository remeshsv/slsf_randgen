classdef savedresult < handle
    %SAVEDRESULT This result regarding a particular model will be saved in
    %reportsneo folder

    properties
        model_name;
        errors = []; % All final errors associated with this model
        is_err_after_normal_sim = false;
        
    end
    
    methods
         function obj = savedresult(model_name)
             obj.model_name = model_name;
         end
    
    end
    
end

