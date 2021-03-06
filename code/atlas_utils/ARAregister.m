function ARAregister(varargin)
% Register sample brain to the ARA and create transform parameters for sparse points
%
% function ARAregister('param1',val1, 'param2',val2, ...)
%
% Purpose
% Register sample brain to the ARA (Allen Reference Atlas) in various ways. 
% This function is run after downsampleVolumeAndData
% By default this function:
% 1. Registers the ARA template TO the sample.
% 2. Registers the sample to the ARA template.
% 3. If (2) was done, the inverse transform of it is also calculated.
%
% The results are saved to downsampleDir
%
% If no inputs are provided it looks for the default down-sample directory. 
% The ARA to use is infered from the file names in downsampleDir. 
% NOTE: once this function has been run you can transform the sparse points to ARA
%       again simply by running invertExportedSparseFiles from the experiment root dir.
%
%
% Inputs (optional parameter/value pairs)
% 'downsampleDir' - String defining the directory that contains the downsampled data. 
%                   By default uses value from toolbox YML file (see source code for now).
% ara2sample - [bool, default true] whether to register the ARA to the sample
% sample2ara - [bool, default true] whether to register the sample to the ARA
% suppressInvertSample2ara - [bool. default false] if true, the inverse transform is not
%                            calculated if the sample2ara transform is performed.
%                            You need the inverse transform if you want to go on to 
%                            register sparse points to the ARA. 
% elastixParams - paths to parameter files. By default we use those in ARA_tools/elastix_params/
%
%
% Outputs
% none
%
%
% For more details see the repository ReadMe file and als see the wiki
% (https://bitbucket.org/lasermouse/ara_tools/wiki/Example_1_basic_registering). 
%
%
% Examples
% - Run with defaults
% >> ARAregister
%
% - Run with another set of parameter files
% >> ARAregister('elastix_params','ParamBSpline.txt'})
%
%
% Rob Campbell - Basel, 2015



%Parse input arguments
S=settings_handler('settingsFiles_ARAtools.yml');

params = inputParser;
params.CaseSensitive=false;

params.addParamValue('downsampleDir',fullfile(pwd,S.downSampledDir),@ischar)
params.addParamValue('ara2sample',true,@(x) islogical(x) || x==1 || x==0)
params.addParamValue('sample2ara',true,@(x) islogical(x) || x==1 || x==0)
params.addParamValue('suppressInvertSample2ara',false,@(x) islogical(x) || x==1 || x==0)

toolboxPath = fileparts(which(mfilename));
toolboxPath = fileparts(fileparts(toolboxPath));
elastix_params_default = {fullfile(toolboxPath,'elastix_params','01_ARA_affine.txt'),
                fullfile(toolboxPath,'elastix_params','02_ARA_bspline.txt')};
params.addParamValue('elastixParams',elastix_params_default,@iscell)


params.parse(varargin{:});
downsampleDir = params.Results.downsampleDir;
ara2sample = params.Results.ara2sample;
sample2ara = params.Results.sample2ara;
suppressInvertSample2ara = params.Results.suppressInvertSample2ara;
elastixParams = params.Results.elastixParams;

if ~exist(downsampleDir,'dir')
    fprintf('Failed to find downsampled directory %s\n', downsampleDir), return
end

if sample2ara && suppressInvertSample2ara
    invertSample2ara = false;
else
    invertSample2ara = true ;
end

%Check that the elastixParams are there
for ii=1:length(elastixParams)
    if ~exist(elastixParams{ii},'file')
        error('Can not find elastix param file %s',elastixParams{ii})
    end
end





%Figure out which atlas to use
mhdFile = getDownSampledMHDFile;
if isempty(mhdFile)
    return %warning message already issued
end

templateFile = getARAfnames;
if isempty(templateFile)
    return  %warning message already issued
end

%The path to the sample file
sampleFile = fullfile(downsampleDir,mhdFile);
if ~exist(sampleFile,'file')
    fprintf('Can not find sample file at %s\n', sampleFile), return
end


%load the images
fprintf('Loading image volumes...')
templateVol = mhd_read(templateFile);
sampleVol = mhd_read(sampleFile);
fprintf('\n')


%We should now be able to proceed with the registration. 
if ara2sample

    fprintf('Beginning registration of ARA to sample\n')
    %make the directory in which we will conduct the registration
    elastixDir = fullfile(downsampleDir,S.ara2sampleDir);
    if ~mkdir(elastixDir)
        fprintf('Failed to make directory %s\n',elastixDir)
    else
        fprintf('Conducting registration in %s\n',elastixDir)
        elastix(templateVol,sampleVol,elastixDir,elastixParams)

        %optionally remove files used to conduct registration 
        if S.removeMovingAndFixed
            delete(fullfile(elastixDir,[S.ara2sampleDir,'_moving*']))
            delete(fullfile(elastixDir,[S.ara2sampleDir,'_target*']))
        end
    end

end

if sample2ara
    fprintf('Beginning registration of sample to ARA\n')

    %make the directory in which we will conduct the registration
    elastixDir = fullfile(downsampleDir,S.sample2araDir);
    if ~mkdir(elastixDir)
        fprintf('Failed to make directory %s\n',elastixDir)
    else
        fprintf('Conducting registration in %s\n',elastixDir)
        elastix(sampleVol,templateVol,elastixDir,elastixParams)
    end

if ~suppressInvertSample2ara
        fprintf('Beginning inversion of sample to ARA\n')
        inverted=invertElastixTransform(elastixDir);
        save(fullfile(elastixDir,S.invertedMatName),'inverted')

        %Now we can transform the sparse points files 
        invertExportedSparseFiles(inverted)
    end
    if S.removeMovingAndFixed
        delete(fullfile(elastixDir,[S.sample2araDir,'_moving*']))
        delete(fullfile(elastixDir,[S.sample2araDir,'_target*']))
    end
end

fprintf('\nFinished\n')