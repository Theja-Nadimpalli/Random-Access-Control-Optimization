% Parameters
numDevices = 300;        % Number of devices
numSlots = 1000;          % Total number of time slots
minCW = 24;              % Minimum contention window size
maxCW = 1024;            % Maximum contention window size
numPreambles = 10;       % Number of available preambles (typical in NB-IoT)
algorithms = {'BEB', 'LILD', 'Adaptive'}; % Algorithms to compare

% Results storage
throughput = zeros(1, length(algorithms));
fairness = zeros(1, length(algorithms));
avgAccessDelay = zeros(1, length(algorithms));
collisionProb = zeros(1, length(algorithms));

for algoIdx = 1:length(algorithms)
    % Initialize variables
    CW = minCW * ones(1, numDevices); % Contention window for each device
    backoffTimers = arrayfun(@(cw) randi([0, cw - 1]), CW); % Random backoff timers
    successfulTransmissions = 0;     
    collisions = 0;                   
    delays = zeros(1, numDevices);    % Access delay for each device
    transmissions = zeros(1, numDevices); % Transmission count for fairness
    successfullyTransmittedDevices = false(1, numDevices); % Track devices that have successfully transmitted
    
    % Simulation loop
    for t = 1:numSlots
        % Identify devices ready to transmit (excluding those who already transmitted)
        transmittingDevices = find(backoffTimers == 0 & ~successfullyTransmittedDevices);
        
        if isempty(transmittingDevices)
            continue; % Skip if no devices are ready to transmit
        end
        
        % Randomly assign preambles to transmitting devices
        preambleAssignments = randi([1, numPreambles], size(transmittingDevices));
        [uniquePreambles, ~, indices] = unique(preambleAssignments);
        
        for i = 1:length(uniquePreambles)
            devicesOnPreamble = transmittingDevices(indices == i);
            if length(devicesOnPreamble) == 1
                % Successful transmission
                successfulTransmissions = successfulTransmissions + 1;
                device = devicesOnPreamble;
                delays(device) = delays(device) + t; % Record delay
                transmissions(device) = transmissions(device) + 1;
                successfullyTransmittedDevices(device) = true; % Mark as successfully transmitted

                % Update CW based on algorithm
                switch algorithms{algoIdx}
                    case 'BEB'
                        CW(device) = minCW; % Reset to minimum CW
                    case 'LILD'
                        CW(device) = max(minCW, CW(device) - 1); % Decrease linearly
                    case 'Adaptive'
                        CW(device) = max(minCW, CW(device) - round(CW(device) * 0.1)); % Adaptive decrease
                end
                
                backoffTimers(device) = randi([0, CW(device) - 1]);
            else
                % Collision
                collisions = collisions + 1;
                for device = devicesOnPreamble
                    % Update CW based on algorithm
                    switch algorithms{algoIdx}
                        case 'BEB'
                            CW(device) = min(CW(device) * 2, maxCW); % Double CW
                        case 'LILD'
                            CW(device) = min(CW(device) + 1, maxCW); % Linear increase
                        case 'Adaptive'
                            CW(device) = min(CW(device) + round(CW(device) * 0.7), maxCW); % Adaptive increase
                    end
                    
                    backoffTimers(device) = randi([0, CW(device) - 1]);
                end
            end
        end
        
        % Update backoff timers for devices that are not successful
        backoffTimers(backoffTimers > 0) = backoffTimers(backoffTimers > 0) - 1;
    end
    
    % Calculate metrics
    throughput(algoIdx) = successfulTransmissions / numSlots;
    
    % Update fairness metric: consider only devices that have transmitted at least once
    if any(transmissions)
        fairness(algoIdx) = (sum(transmissions)^2) / (numDevices * sum(transmissions.^2));
    else
        fairness(algoIdx) = 0; % No successful transmissions, fairness is 0
    end
    
    % Calculate the average access delay: consider only devices with successful transmissions
    if any(transmissions)
        avgAccessDelay(algoIdx) = mean(delays(transmissions > 0));
    else
        avgAccessDelay(algoIdx) = NaN; % No successful transmissions
    end
    
    collisionProb(algoIdx) = collisions / numSlots;
end

disp('Throughput:'); disp(throughput);
disp('Fairness:'); disp(fairness);
disp('Average Access Delay:'); disp(avgAccessDelay);
disp('Collision Probability:'); disp(collisionProb);


figure;
subplot(2, 2, 1); 
bar(throughput);
set(gca, 'XTickLabel', algorithms);
ylabel('Throughput');
title('Throughput Comparison');

subplot(2, 2, 2); % 2x2 grid, position 2
bar(fairness);
set(gca, 'XTickLabel', algorithms);
ylabel('Fairness');
title('Fairness Comparison');

subplot(2, 2, 3); 
bar(avgAccessDelay);
set(gca, 'XTickLabel', algorithms);
ylabel('Average Access Delay');
title('Access Delay Comparison');

subplot(2, 2, 4); 
bar(collisionProb);
set(gca, 'XTickLabel', algorithms);
ylabel('Collision Probability');
title('Collision Probability Comparison');

sgtitle('Performance Metrics Comparison'); 
