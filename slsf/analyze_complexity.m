classdef analyze_complexity < handle
    %ANALYZE_COMPLEXITY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant = true)
        MODEL_NAME = 1;
        BLOCK_COUNT_AGGR = 2;
        BLOCK_COUNT_ROOT = 3;
        CYCLOMATIC = 4;
        SUBSYSTEM_COUNT_AGGR = 5;
        SUBSYSTEM_DEPTH_AGGR = 6;
        LIBRARY_LINK_COUNT = 7;
        
        BP_LIBCOUNT_GROUPLEN = 20;  % length of group for Metric 9
    end
    
    properties
        base_dir = '';
        % types of lists supported: example,cyfuzz,openSource
        exptype = 'example';
        
        % lists containing models
        % examples = {'sldemo_fuelsys','sldemo_mdlref_variants_enum','sldemo_mdlref_basic','untitled2'};

%         examples = {'sldemo_mdlref_basic','sldemo_mdlref_variants_enum','sldemo_mdlref_bus','sldemo_mdlref_conversion','sldemo_mdlref_counter_bus','sldemo_mdlref_counter_datamngt','sldemo_mdlref_dsm','sldemo_mdlref_dsm_bot','sldemo_mdlref_dsm_bot2','sldemo_mdlref_F2C'};
%         examples = {'sldemo_mdlref_basic'};
%         examples = {'sldemo_mdlref_bus'};
        examples = {'sldemo_mdlref_basic', 'sldemo_mdlref_bus'};
%         examples = {'untitled'};
        
        openSource = {'hyperloop_arc','staticmodel'};
        cyfuzz = {'sldemo_mdlref_basic','sldemo_mdlref_variants_enum'};
        
        data = cell(1, 7);
        di = 1;
        
        % array containing blockTypes to check for child models in a model
        childModelList = {'SubSystem','ModelReference'};
        % maps for storing metrics per model
        map;
        blockTypeMap;
        childModelMap;
        childModelPerLevelMap;
        
        % global vectors storing data for box plot for displaying some
        % metrics that need to be calculated for all models in a list
        boxPlotChildModelReuse;
        boxPlotBlockCountHierarchyWise;
        boxPlotChildRepresentingBlockCount;
        
        bp_SFunctions;
        bp_lib_count;
        
        
        % model classes
        model_classes;
        
        max_level = 5;  % Max hierarchy levels to follow
        
        blocktype_library_map; % Map, key is blocktype, value is the library
        libcount_single_model;  % Map, keys are block-library; values are count (how many time a block from that library occurred in a single model)
        blk_count;
        
    end
    
    methods
        
        
        function obj = init_excel_headers(obj)
            obj.data{1, obj.MODEL_NAME} = 'Model name';
            obj.data{1, obj.BLOCK_COUNT_AGGR} = 'BC';
            obj.data{1, obj.BLOCK_COUNT_ROOT} = 'BC(R)';
            obj.data{1, obj.CYCLOMATIC} = 'CY';
            obj.data{1, obj.SUBSYSTEM_COUNT_AGGR} = 'Ss cnt';
            obj.data{1, obj.SUBSYSTEM_DEPTH_AGGR} = 'Ss dpt';
            obj.data{1, obj.SUBSYSTEM_DEPTH_AGGR} = 'Ss dpt';
            obj.data{1, obj.LIBRARY_LINK_COUNT} = 'LibLink cnt';
        end
        
        function  obj = analyze_complexity()
            obj.blocktype_library_map = util.getLibOfAllBlocks();
            obj.model_classes = mymap('example', 'Simulink Examples', 'opensource', 'Open Source', 'cyfuzz', 'CyFuzz');
        end
        
        function start(obj, exptype)
            % Start a single experiment
            obj.exptype = exptype;
            obj.init_excel_headers();
            switch obj.exptype
                case 'example'
                    obj.analyze_all_models_from_a_class();
                case 'opensource'
                    obj.examples = obj.openSource;
                    obj.analyze_all_models_from_a_class();
                case 'cyfuzz'
                    obj.examples = obj.cyfuzz;
                    obj.analyze_all_models_from_a_class();
                otherwise
                    error('Invalid Argument');
            end
            %obj.write_excel();
            obj.renderAllBoxPlots();
            disp(obj.data);
        end
           
        function analyze_all_models_from_a_class(obj)
            fprintf('Analyzing %s\n', obj.exptype);
            % intializing vectors for box plot
            obj.boxPlotChildModelReuse = zeros(numel(obj.examples),1);
            % max hierarchy level we add to our box plot is 5.
            obj.boxPlotBlockCountHierarchyWise = zeros(numel(obj.examples),obj.max_level);
            obj.boxPlotBlockCountHierarchyWise(:) = NaN; % Otherwise boxplot will have wrong statistics by considering empty cells as Zero. 
            % we will only count upto level 5 as this is our requirement.
            % some models may have more than 5 hierarchy levels but they are rare.
            obj.boxPlotChildRepresentingBlockCount = zeros(numel(obj.examples),obj.max_level); 
            obj.boxPlotChildRepresentingBlockCount(:) = NaN;
            
            obj.blockTypeMap = mymap();
            
            % S-Functions
            obj.bp_SFunctions = boxplotmanager();
            
            % Lib count: metric 9
            obj.bp_lib_count = boxplotmanager(obj.BP_LIBCOUNT_GROUPLEN);  % Max 10 character is allowed as group name
            
            % loop over all models in the list
            for i = 1:numel(obj.examples)
                s = obj.examples{i};
                open_system(s);
             
                % initializing maps for storing metrics
                obj.map = mymap();
                obj.childModelPerLevelMap = mymap();
                obj.childModelMap = mymap();
                obj.libcount_single_model = mymap();
                obj.blk_count = 0;
                
                % API function to obtain metrics
                obj.do_single_model(s);
                
                % Our recursive function to obtain metrics that are not
                % supported in API
                obj.obtain_hierarchy_metrics(s,1,false);
                
                % display metrics calculated
                disp('[DEBUG] Number of blocks Level wise:');
                disp(obj.map.data);
                
                disp('[DEBUG] Number of child models with the number of times being reused:');
                disp(obj.childModelMap.data);
                
                obj.calculate_child_model_ratio(obj.childModelMap,i);
                obj.calculate_number_of_blocks_hierarchy(obj.map,i);
                obj.calculate_child_representing_block_count(obj.childModelPerLevelMap,i);
                obj.calculate_lib_count(obj.libcount_single_model, i);
                
                close_system(s);
            end
        end
        
        function renderAllBoxPlots(obj)
%             obj.calculate_number_of_specific_blocks(obj.blockTypeMap);
            obj.calculate_metrics_using_api_data();
            
            % rendering Metric 1: boxPlot for child model reuse %
            % TODO render later, when data for all classes are available.
            figure
            boxplot(obj.boxPlotChildModelReuse);
            xlabel('Classes');
            ylabel('% Reuse');
            title('Metric 1: Child Model Reuse(%)');
            
            % rendering boxPlot for block counts hierarchy wise
            figure
%             disp('[DEBUG] Boxplot metric 3');
%             obj.boxPlotBlockCountHierarchyWise
            boxplot(obj.boxPlotBlockCountHierarchyWise);
            ylabel('Number Of Blocks');
            title(['Metric 3: Block Count across Hierarchy in ' obj.model_classes.get(obj.exptype)]);
            
            % rendering boxPlot for child representing blockcount
            figure
            disp('[DEBUG] Box Plot: Child representing blocks...');
%             obj.boxPlotChildRepresentingBlockCount
            boxplot(obj.boxPlotChildRepresentingBlockCount);
            ylabel('Number Of Child-representing Blocks');
            title('Metric 5: Child-Representing blocks(across hierarchy levels)');
            
            % S-Functions count
            obj.bp_SFunctions.draw('Metric 20 (Number of S-Functions)', 'Hierarchy Levels', 'Block Count');
            
            % Lib Count (Metric 9)
            obj.bp_lib_count.draw(['Metric 9 (Library Participation) in ' obj.model_classes.get(obj.exptype)], 'Simulink library', 'Blocks from this library (%)');
            
        end
        
        function calculate_child_representing_block_count(obj,m,modelCount)
            for k = 1:m.len_keys()
                levelString = strsplit(m.key(k),'x');
                level = str2double(levelString{2});
                if level<=obj.max_level
                    assert(isnan(obj.boxPlotChildRepresentingBlockCount(modelCount,level)));
                    obj.boxPlotChildRepresentingBlockCount(modelCount,level) = m.get(m.key(k));
                end
            end
        end
        
        function calculate_number_of_specific_blocks(obj,m)
            m.keys();
            keys = m.data_keys();
            disp('Number of specific blocks with their counts:');
            %disp(m.data);
            vectorTemp = strings(numel(keys),1);
            vectorTemp(:,1)=keys;
            
            countTemp = zeros(numel(keys),2);
            for k = 1:numel(keys)
               countTemp(k,1)=k;
               countTemp(k,2)=m.data.(keys{k});
            end
            
            sortedVector = sortrows(countTemp,2);
            fprintf('%25s | Count\n','Block Type');
            for i=numel(keys)-10:numel(keys)
                fprintf('%25s | %3d\n',vectorTemp(sortedVector(i,1)),sortedVector(i,2));
            end
            
            % rendering boxPlot for number of specific blocks used across
            % all models in the list.
            figure
            boxplot(sortedVector(end-10:end,2));
            ylabel(obj.exptype);
            title('Metric 7: Number of Specific blocks');
        end
        
        function calculate_number_of_blocks_hierarchy(obj,m,modelCount)
            
            for k = 1:m.len_keys()
                levelString = strsplit(m.key(k),'x');
                level = str2double(levelString{2});
                
%                 disp('debug');
%                 modelCount
%                 level
                
                if level <=5
%                     obj.boxPlotBlockCountHierarchyWise(modelCount,level)
                    assert(isnan(obj.boxPlotBlockCountHierarchyWise(modelCount,level)));
                    v = m.get(m.key(k));
%                     if v == 0
%                         disp('v is zero');
%                         v = NaN;
%                     else
%                         fprintf('V is not zero:%d\n', v);
%                     end
                    obj.boxPlotBlockCountHierarchyWise(modelCount,level) =  v;
                    
                    % Cross-validation
                    if level == 1
                        assert(v == obj.data{modelCount + 1, obj.BLOCK_COUNT_ROOT});
                    end
                    
                end
                
                
            end
        end
        
        function calculate_metrics_using_api_data(obj)
            [row,~]=size(obj.data);
            aggregatedBlockCount = zeros(row-1,1);
            cyclomaticComplexityCount = zeros(row-1,1);
            %skip the first row as it is the column name
            for i=2:row 
                aggregatedBlockCount(i-1,1)=obj.data{i,2};
%                 if ~isnan(obj.data{i,4})

                if isempty(obj.data{i, 4})
                    cyclomaticComplexityCount(i-1,1)= NaN;
                else
                    cyclomaticComplexityCount(i-1,1)=obj.data{i,4};
                end
            end
            
            %rendering boxPlot for block counts hierarchy aggregated
%             disp('[DEBUG] Aggregated block count');
%             aggregatedBlockCount
            figure
            boxplot(aggregatedBlockCount);
            xlabel(obj.exptype);
            ylabel('Number Of Blocks');
            title('Metric 2: Block Count Aggregated');
            
            %rendering boxPlot for cyclomatic complexity
            figure
            boxplot(cyclomaticComplexityCount);
            xlabel(obj.exptype);
            ylabel('Count');
            title('Metric 6: Cyclomatic Complexity Count');
        end
        
        function calculate_lib_count(obj, m, model_index)
            fprintf('[D] Calculate Lib Count Metric\n');
%             num_blocks = obj.data{model_index + 1, obj.BLOCK_COUNT_AGGR};
            count_blocks = 0;
            for i = 1:m.len_keys()
                k = m.key(i);
                ratio = m.get(k)/obj.blk_count * 100;
                obj.bp_lib_count.add(round(ratio), k);
                fprintf('\t[D] calculate lib count: library: %s, ratio: %.2f\n', k, ratio);
                count_blocks = count_blocks + m.get(k);
            end
            assert(count_blocks == obj.blk_count);
%             fprintf('[D] Final Count: %d; actual: %d; Manual: %d\n', count_blocks, num_blocks, obj.blk_count);
        end
        
        function calculate_child_model_ratio(obj,m,modelCount)
            reusedModels = 0;
            newModels = m.len_keys();
            
            for k = 1:newModels
                x = m.get(m.key(k));
                if x > 1
                    reusedModels = reusedModels+x-1;
                end
            end
            
            if newModels > 0
                % formula to calculate the reused model ratio
                obj.boxPlotChildModelReuse(modelCount) = reusedModels/(newModels+reusedModels);
            else
                obj.boxPlotChildModelReuse(modelCount) = NaN;
            end
        end
        
        %our recursive function to calculate metrics not supported by API
        function count = obtain_hierarchy_metrics(obj,sys,depth,isModelReference)  
            if isModelReference
                mdlRefName = get_param(sys,'ModelName');
                load_system(mdlRefName);
                all_blocks = find_system(mdlRefName,'SearchDepth',1);
                all_blocks = all_blocks(2:end);
%                 fprintf('[V] ReferencedModel %s; depth %d\n', char(mdlRefName), depth);
            else
                all_blocks = find_system(sys,'SearchDepth',1);
%                 fprintf('[V] SubSystem %s; depth %d\n', char(sys), depth);
            end
            
            count=0;
            childCountLevel=0;
            count_sfunctions = 0;
            
            [blockCount,~] =size(all_blocks);
            
            %skip the root model which always comes as the first model
            for i=1:blockCount
                currentBlock = all_blocks(i);
                if ~ strcmp(currentBlock, sys) 
                    blockType = get_param(currentBlock, 'blocktype');
                    obj.blockTypeMap.inc(blockType{1,1});
                    obj.libcount_single_model.inc(obj.get_lib(blockType{1, 1}));
                    if util.cell_str_in(obj.childModelList,blockType)
                        % child model found
                        
                        if strcmp(blockType,'ModelReference')
                            childCountLevel=childCountLevel+1;
                            
                            modelName = get_param(currentBlock,'ModelName');
                            is_model_reused = obj.childModelMap.contains(modelName);
                            obj.childModelMap.inc(modelName{1,1});
                            
                            if ~ is_model_reused
                                % Will not count the same referenced model
                                % twice.
                                obj.obtain_hierarchy_metrics(currentBlock,depth+1,true);
                            end
                        else
                            inner_count  = obj.obtain_hierarchy_metrics(currentBlock,depth+1,false);
                            if inner_count > 0
                                % There are some subsystems which are not
                                % actually subsystems, they have zero
                                % blocks. Also, masked ones won't show any
                                % underlying implementation
                                childCountLevel=childCountLevel+1;
                            end
                        end
                    elseif util.cell_str_in({'S-Function'}, blockType)
                        % S-Function found
                        count_sfunctions = count_sfunctions + 1;
                    end
                    count=count+1;
                    obj.blk_count = obj.blk_count + 1;
                end
            end
            
            mapKey = num2str(depth);
            
%             fprintf('\tBlock Count: %d\n', count);
            
            
            if count >0
                obj.map.insert_or_add(mapKey, count);
            end
            
            obj.childModelPerLevelMap.insert_or_add(mapKey, childCountLevel);
            
            obj.bp_SFunctions.add(count_sfunctions, int2str(depth));
            
        end
        
        function ret = get_lib(obj, block_type)
            if obj.blocktype_library_map.contains(block_type)
                ret = obj.blocktype_library_map.get(block_type);
            else
                ret = 'Others';
            end
        end
        
        
        function obj = write_excel(obj)
            %filename = 'MetricResults.xlsx';
            %disp(obj.data);
            %xlswrite(filename,obj.data);
        end
        
        function do_single_model(obj, sys)
            obj.di = obj.di + 1;
            obj.data{obj.di, obj.MODEL_NAME} = sys;
            
            metric_engine = slmetric.Engine();

            % Include referenced models and libraries in the analysis, these properties are on by default
            metric_engine.AnalyzeModelReferences = 1;
            metric_engine.AnalyzeLibraries = 1;
            
            metrics ={ 'mathworks.metrics.SimulinkBlockCount', 'mathworks.metrics.SubSystemCount', 'mathworks.metrics.SubSystemDepth', 'mathworks.metrics.CyclomaticComplexity', 'mathworks.metrics.LibraryLinkCount'};
            
            setAnalysisRoot(metric_engine, 'Root',  sys);
            execute(metric_engine, metrics);
            res_col = getMetrics(metric_engine, metrics);
            
            
            for n=1:length(res_col)
                if res_col(n).Status == 0
                    result = res_col(n).Results;

                    for m=1:length(result)
                        
                        switch result(m).MetricID
                            case 'mathworks.metrics.SimulinkBlockCount'
                                if strcmp(result(m).ComponentPath, sys)
                                    obj.data{obj.di, obj.BLOCK_COUNT_AGGR} = result(m).AggregatedValue;
                                    obj.data{obj.di, obj.BLOCK_COUNT_ROOT} = result(m).Value;
                                end
                            case 'mathworks.metrics.CyclomaticComplexity'
                                if strcmp(result(m).ComponentPath, sys)
                                    obj.data{obj.di, obj.CYCLOMATIC} = result(m).AggregatedValue;
                                end
                            case 'mathworks.metrics.SubSystemCount'
                                if strcmp(result(m).ComponentPath, sys)
                                    obj.data{obj.di, obj.SUBSYSTEM_COUNT_AGGR} = result(m).AggregatedValue;
                                end
                            case 'mathworks.metrics.SubSystemDepth'
                                if strcmp(result(m).ComponentPath, sys)
                                    obj.data{obj.di, obj.SUBSYSTEM_DEPTH_AGGR} = result(m).Value;
                                end
                            case 'mathworks.metrics.LibraryLinkCount'
                                 if strcmp(result(m).ComponentPath, sys)
                                    obj.data{obj.di, obj.LIBRARY_LINK_COUNT} = result(m).Value;
                                end
                        end
                    end
                else
                    disp(['No results for:', result(n).MetricID]);
                end
                disp(' ');
            end
        end
    end
    
    methods(Static)
        function go(exptype)
            disp('--- Complexity Analysis --');
            analyze_complexity().start(exptype);
        end
    end
end
