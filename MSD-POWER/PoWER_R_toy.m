% This file contains a sample implementation of PoWER
% The required motor primitive code can be downloaded from
% http://www-clmc.usc.edu/Resources/Software
% 
% The algorithm is implemented with a number of simplifications:
% - the variance of the exploration is constant over trials
% - the exploration is constant during the trial
%   (as the motor primitives employ basis functions that are localized in time 
%   which are only active for a short period of time,
%   time-varying exploration does not have large effetcs)
% - the return is used instead of the state-action value function
% - always only one basis function is active

clear all;
close all;
clc;

% time step
dt = 0.005;

% length of the episode
T = 1;

% number of basis functions
n_rfs = 10;

ID = 1;
goal = 1.5;

% number of iterations
n_iter = 10000;

% initialize the motor primitive and storage variables
dcp('init',ID,n_rfs,'PoWER');

rt = 0:dt:T;

y = zeros(1,length(rt));
yd = zeros(1,length(rt));
ydd = zeros(1,length(rt));

Return = zeros(1,n_iter+1);
s_Return = zeros(n_iter+1,2);
param = zeros(n_rfs,n_iter+1);
randn('state',20);

% set the variance
variance = 4000.*ones(n_rfs,1);

% start with all parameters set to zero
param(:,1) = zeros(n_rfs,1); 
current_param = param(:,1);

% apply the new parameters to the motor primitive
dcp('change',ID,'w',param(:,1));

% reset the motor primitive
dcp('reset_state',ID);
dcp('set_goal',ID,goal,1);

% run the motor primitive
for i=1:length(rt)
    [y(i),yd(i),ydd(i)] = dcp('run',ID,T,dt);
end

% do the iterations
for iter=1:n_iter
    if (mod(iter,100)==0)
        disp(['Iter ', num2str(iter)]);
    end
    
    % calculate the return of the previous rollout
    % the policy starts at 0 and the distance to 1 is punished
    Return(iter) = sum(exp(-abs(1-y)))/length(rt);
    
    % this lookup table will be used for the importance sampling
    s_Return(1,:) = [Return(iter) iter];
    s_Return = sortrows(s_Return);
    
    % update the policy parameters
    param_nom = zeros(n_rfs,1);
    param_dnom = 0;
    
    % calculate the expectations (the normalization is taken care of by the division)
    % as importance sampling we take the 10 best rollouts
    for i=1:min(iter,10)
        % get the rollout number for the 10 best rollouts
        j = s_Return(end+1-i,2);
        % calculate the exploration with respect to the current parameters
        temp_explore = (param(:,j)-current_param);
        % as we use the return, always have the same exploration variance,
        % and assume that always only one basis functions is active we get 
        % these simple sums
        param_nom = param_nom + temp_explore*Return(j);
        param_dnom = param_dnom + Return(j);
    end
    
    % update the parameters
    param(:,iter+1) = current_param + param_nom./(param_dnom+1.e-10);
    % set the new mean of the parameters
    current_param = param(:,iter+1);
    
    % in the last rollout we want to get the return without exploration
    if iter~=n_iter
        param(:,iter+1) = param(:,iter+1) + variance.^.5.*randn(n_rfs,1);
    end
    
    % apply the new parameters to the motor primitve
    dcp('change',ID,'w',param(:,iter+1));

    % reset the motor primitive
    dcp('reset_state',ID);
    dcp('set_goal',ID,goal,1);
    
    % run the motor primitive
    for i=1:length(rt)
        [y(i),yd(i),ydd(i)] = dcp('run',ID,T,dt);
    end
end

% calculate the return of the final rollout
Return(iter+1) = sum(exp(-abs(1-y)))/length(rt);

% plot the return over the rollouts
figure(1);
plot(Return);
ylabel('return');
xlabel('rollouts');

disp(['Final Return ', num2str(Return(end))]);
