clc, clear
%% ================= Simulation of LODCO-Based eps-Greedy Algorithm =================

% ======================================================================




% �˴����ڼ�ֵ�ԵĴ�����Ȼ�����⣡




% =====================================================================




%% ������������
k = 1e-28;                        % ��Ч���ص���
tau = 0.002;                      % ʱ��Ƭ����(s)
tau_d = 0.002;                    % ��������ִ��ʱ���deadline(s)
phi = 0.002;                      % �������ĳͷ���Ȩ��(s)
omega = 1e6;                      % ����������(Hz)
sigma = 1e-13;                    % ���ն˵���������(W)
p_tx_max = 1;                     % �ƶ��豸����书��(W)
f_max = 1.5e9;                    % �ƶ��豸���CPUʱ������Ƶ��(Hz)
E_max = 0.002;                    % �����������ŵ���(J)
L = 1000;                         % һ���������Ĵ�С(bit)
X = 737.5;                        % �ƶ��豸ִ��һ��������������ʱ�����ڸ���
W = 737500;                       % �ƶ��豸����ִ��һ��������������ʱ�����ڸ���(L*X)
E_H_max = 48e-6;                  % �ռ����������ӵľ��ȷֲ�����(J)
g0 = 1e-4;                        % ·����ʧ����(dBת��֮�����ֵ��)
d0 = 1;                           % ���������ƶ��豸֮�����Ծ���(m)

%% ��������
N = 10;                           % �ƶ��豸��Ŀ
M = 20;                           % MEC����������
T = 1000;                         % ʱ��Ƭ����
E_min = 0.02e-3;                  % ����ʹ���½�(J)
V = 1e-5;                         % LODCO��penalty���Ȩ��(J^2/second)
rho = 0.6;                        % ��������ִ�ĸ���
eps = 0.25;                       % ����̰���㷨�ľ���

% ʵ���ܺ�����
E_max_hat = min(max(k*W*(f_max^2), p_tx_max*tau), E_max);
theta = E_max_hat + V*phi/E_min;        % �Ŷ�����

%% �м�����洢           
B = zeros(T, N);                        % N���ƶ��豸��ʵ�ʵ���
B_hat = zeros(T, N);                    % N���ƶ��豸���������
e = zeros(T, N);                        % N���ƶ��豸�������ռ�
indicator = zeros(T, N);                % ��1,2,3,4�ֱ��ʾ����ִ�С�ж��ִ�С�drop(ǰ��������ζ�������񵽴�)�Լ�û�����񵽴�
f = zeros(T, N);                        % N���ƶ��豸����ִ�е�Ƶ��
p = zeros(T, N);                        % N���ƶ��豸ж��ִ�еĴ��书��
local_execution_delay = zeros(T, N);    % N���ƶ��豸��local execution delay
remote_execution_delay = zeros(T, N);   % N���ƶ��豸��remote execution delay
cost = zeros(T, N);                     % N���ƶ��豸��execution cost
E_local = zeros(T, N);                  % N���ƶ��豸����ִ�е��ܺ�
E_remote = zeros(T, N);                 % N���ƶ��豸ж��ִ�е��ܺ�
E_all = zeros(T, N);                    % N���ƶ��豸�����ܺ�
mode_num = zeros(T,3);                  % ÿһ�зֱ��ʾÿ���б���ִ�С�Զ��ִ�м��������ı���(��ĸΪN��ȥû�����񵽴��)

% �ر�fslove�����
opt = optimset('Display', 'off');

t = 1;
while t <= T
    % ��һ���������ġ�3�еľ�������"�ƶ��豸i-MEC������j-i��j����С�����ӳ�"
    map = [];
    % �洢ÿһ��MEC���������ӵ����ƶ��豸����
    flags = zeros(M, 1);
    % �ֱ𱣴浱ǰ�ƶ��豸����MEC��������J_sֵ
    J_s_matrix = zeros(N, M);
    % �ֱ�洢ÿһ���ƶ��豸�ı���ִ�е��ӳ�J_m�����ξ���ʱʹ��
    J_m = zeros(N, 1);
    % ���������������ֵ
    B_hat(t,:) = B(t,:) - theta;

    for i = 1:N
        %% ��ÿһ���ƶ��豸���׶γ�ʼ��
        %% ���optimal energy harvesting e* (�����Ƿ�����������������ռ�������ͣ��)
        % ����E_H_t
        E_H_t = unifrnd(0, E_H_max);
        if B_hat(t, i) <= 0
            e(t, i) = E_H_t;
        end

        % �Բ�Ŭ���ֲ�������������
        zeta = binornd(1, rho);
        if zeta == 0
            % û�м����������
            indicator(t, i) = 4;
            % f(t, i) = 0; p(t, i) = 0;    Ĭ�ϼ�Ϊ0
        else
            %% ���P_ME
            f_L = max(sqrt(E_min/(k*W)), W/tau_d);
            f_U = min(sqrt(E_min/(k*W)), f_max);
            if f_L <= f_U
                % P_ME�н�
                f0 = power(V/(-2*B_hat(t,i)*k), 1/3);
                if f0 > f_U
                    f(t, i) = f_U;
                elseif f0 >= f_L && f0 <= f_U && B_hat(t,i) < 0
                    f(t, i) = f0;
                elseif f0 < f_L
                    f(t, i) = f_L;
                end
                % �����ʱ��execution delay
                local_execution_delay(t, i) = W / f(t, i);
                % �����ʱ���ܺ�
                E_local(t, i) = k * W * (f(t, i)^2);
                if E_local(t, i) >= B(t, i)
                    disp(['����ִ�е�������![��ʱtΪ', num2str(t), ']']);
                    J_m(i) = inf;    % ����Ϊinf���Ա�֤һ����phiС
                else
                    % �����ʱ��J_m
                    % J_m��������������Ŀ�꺯��ֵ�����ܺĺ��ӳ�ͳһ�任��Ľ�������ǽ������ӳ٣�
                    J_m(i) = -B_hat(t,i)*E_local(t, i) + V*local_execution_delay(t, i);
                end

            else
                disp(['P_ME�޽�![��ʱtΪ', num2str(t), ']']);
                J_m(i) = inf;
            end

            %% ���P_SE
            % ����������������ƶ��豸�ľ���(�޶���0 ~ 80֮��)
            D = unifrnd(0, 100, N, M);
            % ����lambda=1��ָ���ֲ���С�߶�˥���ŵ���������
            gamma = exprnd(1, N, M);
            % �������ƶ��豸��������������ŵ���������
            h = g0*gamma.*power(d0./D, 4);
            % ���浱ǰ�ƶ��豸�����з�������ж��ִ���ӳ�
            remote_execution_delay_tmp = zeros(M, 1);

            for j = 1:M
                tmp_h = h(i,j);
                E_tmp = sigma*L*log(2) / (omega*tmp_h);
                p_L_taud = (power(2, L/(omega*tau_d)) - 1) * (sigma/tmp_h);
                if E_tmp >= E_min
                    p_L = p_L_taud;
                else
                    % ����p_Emin
                    y = @(x)x*L-omega*log2(1+tmp_h*x/sigma)*E_min;
                    %p_Emin = double(vpa(solve(y, 1)));
                    tmp = fsolve(y, [0.0000000001, 1], opt);
                    p_Emin = real(max(tmp));
                    p_L = max(p_L_taud, p_Emin);
                end
                if E_tmp >= E_max
                    p_U = 0;
                else
                    % ����p_Emax
                    %{
                    y = @(x)x*L-omega*log2(1+tmp_h*x/sigma)*E_max;
                    p_Emax = max(fsolve(y, [0.001, 100]));
                    p_U = min(p_tx_max, p_Emax);
                    %}
                    % ��������
                    p_Emax = 25;
                    p_U = 1;
                end
                if p_L <= p_U
                    % P_SE�н�
                    % ����p0
                    tmp = B_hat(t,i);
                    y = @(x)tmp*log2(1+tmp_h*x/sigma) + tmp_h*(V-tmp*x)/(log(2)*(sigma+tmp_h*x));
                    p0 = real(max(fsolve(y, [0.00000000001, 1], opt)));
                    if p_U < p0
                        p(t,i) = p_U;
                    elseif p_L > p0 && B_hat(t,i) < 0
                        p(t,i) = p_L;
                    elseif p_L <= p0 && p_U >= p0 && B_hat(t,i) < 0
                        p(t,i) = p0;
                    end
                    % ����achievable rate
                    r = calAchieveRate(tmp_h, p(t,i), omega, sigma);
                    % �����ʱ���ӳ�
                    remote_execution_delay_tmp(j) = L / r;
                    % �����ʱ���ܺ�
                    E_remote(t, i) = p(t,i)*L / r;
                    if E_remote(t, i) >= B(t, i)
                        disp(['ж��ִ�е�������![��ʱtΪ', num2str(t), ']']);
                        J_s = inf;
                    else
                        % �����ʱ��J_s
                        % J_s��ж��ִ���������Ŀ�꺯��ֵ�������ӳ٣���
                        J_s = -B_hat(t,i)*E_remote(t,i) + V*remote_execution_delay_tmp(j);
                    end
                else
                    disp(['P_SE�޽�![��ʱtΪ', num2str(t), ']']);
                    % ���indicator(t, 2) = 0����
                    J_s = inf;
                end
                J_s_matrix(i,j) = J_s;
            end
            
            % ѡȡ����ѵļ�ֵ�����
            [J_s_best, j_best] = min(J_s_matrix(i,:));
            % �����ʱ��execution delay
            remote_execution_delay(t, i) = remote_execution_delay_tmp(j_best);

            %% Ϊ��i���ƶ��豸ѡȡ���ģʽ
            [~, mode] = min([J_m(i), J_s_best, phi]);
            indicator(t, i) = mode;
            if mode == 2
                %{
                map(i) = j_best;
                map_Js_best = [map_Js_best, J_s_best];
                %}
                map = [map;[i,j_best,J_s_best]];
            end
        end
    end

    %% Ϊ��Щѡ��ж��ִ�е�������������(����ѡģʽ)
    % UB = f_server_max*tau_d/(L*X),ȡf_server_max=f_max��ԼΪ4.0678
    UB = 4;
    while ~isempty(map)
        % �ҵ�ӵ����С�����ӳٵ��ƶ��豸-MEC��������
        [min_Js,index] = min(map(:,3));
        % �ҵ���С�ӳٶ�Ӧ��min_i��min_j
        min_i = map(index,1);
        min_j = map(index,2);
        
        % ��ʱֻ����ж��ִ�У������Ƚ�ж��ִ���Ƿ�Ϊ�������
        if rand() <= eps
            % ��ǰ�ƶ��豸�����ˣ�����������ŵ�ж�ض��󻹿����ٽ�������
            if flags(min_j) <= UB
                % ��map��ɾ���ü�ֵ�Բ�ͬ��һϵ�й�ͬά���ı���
                map(index,:) = [];
                % ��Ӧ��MEC����������1(�ò�����λ�÷����˱仯�����Ĵ˴���Ҫ�޸�)
                flags(min_j) = flags(min_j) + 1;
            else
                % flags(min_j)�Ѵ����ޣ�����Щ���ж�ض���Ϊmin_j���ƶ��豸��ʱ��Ŀ�꺯��ֵ����Ϊinf�������ɴ�
                % (������������Ѿ����ж�صķ��������Բ������κ�Ӱ�죬��Ϊ���ǲ������ٳ�����map��)
                % ��ʱ����豸min_iֻ������ѡ������ŵ�ж�ض���
                J_s_matrix(:, min_j) = inf;
                % ��ʱ�������map��֮��map��������µ�J_s_matrix�������Լ���ֵ

                % Ϊmin_i����ѡ��һ�������ŵ�ж�ض���.�����ƶ��豸������ѡ�ķ�������ʱ������Щ��ѡ�ķ��������ҵ�J_s��С���Ǹ�
                % ��һ�����: ���з�����û��������ѡ
                if min(J_s_matrix(min_i,:)) ~= inf
                    % �ҵ���С���Ǹ�֮�󣬸���map�и��ƶ��豸ѡȡ�ķ������������Ƕ�Ӧ��Js��Сֵ
                    [min_Js_second, min_j_second] = min(J_s_matrix(min_i,:));
                    map(index,2:3) = [min_j_second,min_Js_second];
                    % ����������while�����¿�ʼ�ҵ�ǰ������СJ_sֵ���豸�Ͷ�Ӧ�ķ�����
                    continue;
                % �ڶ������: �ܲ��ң�ÿһ��������������
                else
                    % û�з���������ѡ�ˣ�ֻ������������mode��ѡȡ
                    % ��������ָʾ����
                    [~, mode] = min([J_m(min_i), inf, phi]);
                    indicator(t,i) = mode;
                    % ��map��ɾ���ü�ֵ�Բ�ͬ��һϵ�й�ͬά���ı�������Ϊmapֻ�����ͼж��ִ�е��豸
                    map(index,:) = [];
                end
            end
        else
            [~, mode] = min([J_m(i), J_s_best, phi]);
            if mode == 2
                % ��ǰ����ģʽ��Ϊж��ִ��
                if flags(min_j) <= UB
                    % ��map��ɾ���ü�ֵ�Բ�ͬ��һϵ�й�ͬά���ı���
                    map(index,:) = [];
                    % ��Ӧ��MEC����������1
                    flags(min_j) = flags(min_j) + 1;
                    % ��J_s_matrix(min_i,min_j)��Ϊinf
                    J_s_matrix(min_i,min_j) = inf;
                else
                    if min(J_s_matrix(min_i,:)) ~= inf
                        % �����ƶ��豸������ѡ�ķ�������ʱ�򣬲��������ҵ�����С���Ǹ�
                        % �ҵ���С���Ǹ�֮�󣬸���map�и��ƶ��豸ѡȡ�ķ������������Ƕ�Ӧ��Js��Сֵ
                        [min_Js_second, min_j_second] = min(J_s_matrix(min_i,:));
                        map(index,2:3) = [min_j_second,min_Js_second];
                        % ����������while�����¿�ʼ����С��Js
                        continue;
                    else
                        % û�з���������ѡ�ˣ�ֻ������������mode��ѡȡ
                        % ��������ָʾ����
                        [~, mode] = min([J_m(min_i), inf, phi]);
                        indicator(t,i) = mode;
                        % ��map��ɾ���ü�ֵ�Բ�ͬ��һϵ�й�ͬά���ı���(�˴�������Ҫ����)
                        map(index,:) = [];
                        %{
                        ==min_i�Ѿ����ٳ��ֵĿ��ܣ����û�б�Ҫ�ٽ�J_s_matrix(min_i,min_j)��Ϊinf==
                        J_s_matrix(min_i,min_j) = inf;
                        %}
                    end
                end
            else
                % �����µ�����ģʽ������map��ɾ������ֵ�Լ�ά���ı���
                indicator(t,i) = mode;
                map(index,:) = [];
            end
        end
    end
    
    % ����ÿһ���ƶ��豸��execution cost
    cost(t,indicator(t,:)==1) = local_execution_delay(t,indicator(t,:)==1);
    cost(t,indicator(t,:)==2) = remote_execution_delay(t,indicator(t,:)==2);
    cost(t,indicator(t,:)==3) = phi;
    % ����ÿһ���ƶ��豸�����ܺ�
    E_all(t,indicator(t,:)==1) = E_local(t,indicator(t,:)==1);
    E_all(t,indicator(t,:)==2) = E_remote(t,indicator(t,:)==2);
    E_all(t,indicator(t,:)==3) = 0;

    % �м������
    task_num = N - size(find(indicator(t,:)==4),2);
    local_rate = size(find(indicator(t,:)==1),2)/task_num;
    offloading_rate = size(find(indicator(t,:)==2),2)/task_num;
    drop_rate = size(find(indicator(t,:)==3),2)/task_num;

    mode_num(t,:) = [local_rate,offloading_rate,drop_rate];
    
    disp(['�ڵ�',num2str(t),'��:']);
    disp(['����ִ�е��ƶ��豸ռ��: ',num2str(local_rate)]);
    disp(['ж��ִ�е��ƶ��豸ռ��: ',num2str(offloading_rate)]);
    disp(['���������ƶ��豸ռ��: ',num2str(drop_rate)]);
    disp('-----------------------------------');

    % �ƶ��豸��������
    B(t+1,:) = B(t,:) - E_all(t,:) + e(t,:);
    % ʱ��Ƭ����
    t = t + 1;
end

%% ����ܽ�
disp('--------------��������--------------');
disp(['����ִ�е�ƽ���ƶ��豸ռ��: ', num2str(mean(mode_num(:,1)))]);
disp(['ж��ִ�е�ƽ���ƶ��豸ռ��: ', num2str(mean(mode_num(:,2)))]);
disp(['��������ƽ���ƶ��豸ռ��: ', num2str(mean(mode_num(:,3)))]);