clc, clear
%% ================= Simulation of LODCO-Based Integer Programming =================

%% ������������
k = 1e-28;                        % ��Ч���ص���
tau = 0.002;                      % ʱ��Ƭ����(s)
tau_d = 0.002;                    % ��������ִ��ʱ���deadline(s)
phi = 0.002;                      % �������ĳͷ���Ȩ��(s)
little_phi = 0.007;               % ��Сд��phi��ʾ����ж��ִ�еĽ�����
omega = 1e6;                      % ����������(Hz)
sigma = 1e-13;                    % ���ն˵���������(W)
p_tx_max = 1;                     % �ƶ��豸����书��(W)
f_max = 1.5e9;                    % �ƶ��豸���CPUʱ������Ƶ��(Hz)
E_max = 0.003;                    % �����������ŵ���(J)
L = 1000;                         % һ���������Ĵ�С(bit)
X = 737.5;                        % �ƶ��豸ִ��һ��������������ʱ�����ڸ���
W = 737500;                       % �ƶ��豸����ִ��һ��������������ʱ�����ڸ���(L*X)
g0 = 1e-4;                        % ·����ʧ����(dBת��֮�����ֵ��)
d0 = 1;                           % ���������ƶ��豸֮�����Ծ���(m)

%% ��������
N = 10;                           % �ƶ��豸��Ŀ
M = 5;                            % MEC����������
T = 150;                          % ʱ��Ƭ����
E_min = 0.02e-3;                  % ����ʹ���½�(J)
V = 1e-5;                         % LODCO��penalty���Ȩ��(J^2/second)
rho = 0.6;                        % ��������ִ�ĸ���
E_H_max = 48e-6;                  % �ռ����������ӵľ��ȷֲ�����(J)
eps = 0.1;                        % ����̰���㷨�ľ���

% ʵ���ܺ�����
E_max_hat = min(max(k*W*(f_max^2), p_tx_max*tau), E_max);
theta = E_max_hat + V*phi/E_min;        % �Ŷ�����

%% �м�����洢           
B = zeros(T, N);                        % N���ƶ��豸��ʵ�ʵ���
B_hat = zeros(T, N);                    % N���ƶ��豸���������
e = zeros(T, N);                        % N���ƶ��豸�������ռ�
indicator = zeros(T, N);                % ��1,2,3,4�ֱ��ʾ����ִ�С�ж��ִ�С�drop(ǰ��������ζ�������񵽴�)�Լ�û�����񵽴�
f = zeros(T, N);                        % N���ƶ��豸����ִ�е�Ƶ��(֮�󲻻��õ�)
p = zeros(T, N);                        % N���ƶ��豸ж��ִ�еĴ��书��(֮�󲻻��õ�)
local_execution_delay = zeros(T, N);    % N���ƶ��豸��local execution delay
remote_execution_delay = zeros(T, N);   % N���ƶ��豸��remote execution delay
cost = zeros(T, N);                     % N���ƶ��豸��execution cost(���ȷ��)
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
    % �ֱ𱣴浱ǰ�ƶ��豸����MEC��������J_sֵ(�����ӳ�)
    J_s_matrix = zeros(N, M);
    % �ֱ𱣴浱ǰ�ƶ��豸����MEC���������ܺ�
    E_remote_matrix = zeros(N, M);
    % �ֱ𱣴浱ǰ�ƶ��豸����MEC����������Ѵ��书��
    p_matrix = zeros(N, M);
    % �ֱ�洢ÿһ���ƶ��豸�ı���ִ�е��ӳ�J_m�����ξ���ʱʹ��
    J_m = zeros(N, 1);
    % ���������������ֵ
    B_hat(t,:) = B(t,:) - theta;

    % ����һ������²���Ҫ������ֵ��(��ֱ�Ӹ���intlinporg���)
    useKeyValuePair = 0;
    for i = 1:N
        %% ��ÿһ���ƶ��豸���׶γ�ʼ��
        % �Բ�Ŭ���ֲ�������������
        zeta = binornd(1, rho);
        if zeta == 0
            % û�м����������
            indicator(t, i) = 4;
            f(t, i) = 0; p(t, i) = 0;
        else
            %% ���optimal energy harvesting e*
            % ����E_H_t
            E_H_t = unifrnd(0, E_H_max);
            if B_hat(t,i) <= 0                    % ��ʼֵΪ0������������۴���0������
                e(t, i) = E_H_t;
            end

            %% ���P_ME
            f_L = max(sqrt(E_min/(k*W)), W/tau_d);
            f_U = min(sqrt(E_min/(k*W)), f_max);
            if f_L <= f_U
                % P_ME�н�
                f0 = power(V/(-1*B_hat(t,i)*k), 1/3);
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
                    disp(['P_ME��������![��ʱtΪ', num2str(t), ']']);
                    J_m(i) = inf;    % ����Ϊinf���Ա�֤һ����phiС
                    useKeyValuePair = 1;
                else
                    % �����ʱ��J_m(ֻ�����ӳ٣��������ܺ�)
                    J_m(i) = W/f(t, i);
                end

            else
                disp(['P_ME�޽�![��ʱtΪ', num2str(t), ']']);
                % ���indicator(t, 1) = 0����
                J_m(i) = inf;
                useKeyValuePair = 1;
            end

            %% ���P_SE
            % ����������������ƶ��豸�ľ���(�޶���0 ~ 60֮��)
            D = unifrnd(0, 140, N, M);
            % ����lambda=1��ָ���ֲ���С�߶�˥���ŵ���������
            gamma = exprnd(1, N, M);
            % �������ƶ��豸��������������ŵ���������
            h = g0*gamma.*power(d0./D, 4);

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
                    tmp = fsolve(y, [0.001, 1], opt);
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
                    p0 = real(max(fsolve(y, [0.001, 1], opt)));
                    if p_U < p0
                        p_matrix(i, j) = p_U;
                    elseif p_L > p0 && B_hat(t,i) < 0
                        p_matrix(i, j) = p_L;
                    elseif p_L <= p0 && p_U >= p0 && B_hat(t,i) < 0
                        p_matrix(i, j) = p0;
                    end
                    % ����achievable rate
                    r = calAchieveRate(tmp_h, p_matrix(i, j), omega, sigma);
                    % �����ʱ���ܺ�
                    E_remote(t, i) = p_matrix(i, j) * L/r;
                    E_remote_matrix(i, j) = E_remote(t, i);
                    if E_remote(t, i) >= B(t, i)
                        disp(['P_SE��������![��ʱtΪ', num2str(t), ',�ƶ��豸���Ϊ', num2str(i), ',MEC���������Ϊ', num2str(j), '].']);
                        J_s = inf;
                        useKeyValuePair = 1;
                    else
                        % �����ʱ��J_s(ֻ�����ӳ٣��������ܺ�)
                        J_s = L/r;
                    end
                else
                    disp(['P_SE�޽�![��ʱtΪ', num2str(t), ',�ƶ��豸���Ϊ', num2str(i), '].']);
                    J_s = inf;
                    useKeyValuePair = 1;
                end
                J_s_matrix(i,j) = J_s;
            end
            % �����ʱ��execution delay
            remote_execution_delay(t, i) = min(J_s_matrix(i,:));
            % ������ѵ�execution delay�����Ӧ�ķ��������
            [J_s_best, j_best] = min(J_s_matrix(i,:));
            E_remote(t, i) = E_remote_matrix(i, j_best);
            %% Ϊ��i���ƶ��豸ѡȡ���ģʽ
            [~, mode] = min([J_m(i), J_s_best, phi]);
            indicator(t, i) = mode;
            if mode == 2
                map = [map;[i,j_best,J_s_best]];
            end
        end
    end


    %% ������
    if useKeyValuePair == 0
        % ����intlinprog���        
        % ����Ŀ�꺯��f
        goal = zeros(1,N*(M+2));
        for i = 1:10
            goal(7*i-6:7*i-5) = [local_execution_delay(t,i)-B_hat(t,i)*E_local(t,i),phi];
            goal(7*i-4:7*i) = J_s_matrix(i,:)-B_hat(t,i)*E_remote_matrix(i,:)-little_phi;
        end
        % ����intcon
        intcon = 1:N*(M+2);
        % ����A, b, lb, ub
        A = [0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0;
             0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0;
             0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0;
             0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0;
             0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,1;
             1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0;
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1];
        b = [4;4;4;4;4;1;1;1;1;1;1;1;1;1;1];
        lb = zeros(N*(M+2),1);
        ub = ones(N*(M+2),1);
        % ���ؼ����� (system operation)
        so = intlinprog(goal,intcon,A,b,[],[],lb,ub);
        for i = 1:10
            pos = find(so(7*i-6:7*i)==1);
            if pos == 1
                indicator(t,i) = 1;
            elseif pos == 2
                indicator(t,i) = 3;
            else
                indicator(t,i) = 2;
            end
        end
    else
        % ���ü�ֵ�����
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
                if flags(min_j) <= UB
                    % ��map��ɾ���ü�ֵ�Բ�ͬ��һϵ�й�ͬά���ı���
                    map(index,:) = [];
                    % ��Ӧ��MEC����������1(�ò�����λ�÷����˱仯�����Ĵ˴���Ҫ�޸�)
                    flags(min_j) = flags(min_j) + 1;
                    % ��J_s_matrix(min_i,min_j)��Ϊinf
                    J_s_matrix(min_i,min_j) = inf;
                else
                    if min(J_s_matrix(min_i,:)) ~= inf
                        % �����ƶ��豸������ѡ�ķ�������ʱ�򣬲��������ҵ�����С���Ǹ�
                        % �˴�������Ҫ���䣡�ҵ���С���Ǹ�֮�󣬸���map�и��ƶ��豸ѡȡ�ķ������������Ƕ�Ӧ��Js��Сֵ
                        [min_Js_second, min_j_second] = min(J_s_matrix(min_i,:));
                        map(index,2:3) = [min_j_second,min_Js_second];
                        % ����������while�����¿�ʼ����С��Js
                        continue;
                    else
                        % û�з���������ѡ�ˣ�ֻ������������mode��ѡȡ
                        % ��������ָʾ����
                        [~, mode] = min([J_m(min_i), inf, phi]);
                        indicator(t, i) = mode;
                        % ��map��ɾ���ü�ֵ�Բ�ͬ��һϵ�й�ͬά���ı���(�˴�������Ҫ����)
                        map(index,:) = [];
                        %{
                        ==min_i�Ѿ����ٳ��ֵĿ��ܣ����û�б�Ҫ�ٽ�J_s_matrix(min_i,min_j)��Ϊinf==
                        J_s_matrix(min_i,min_j) = inf;
                        %}
                    end
                end
            else
                [~, mode] = min([J_m(i), J_s_best, phi]);
                if mode == 2
                    % ��ǰ����ģʽ��Ϊж��ִ��
                    if flags(min_j) <= UB
                        % ��map��ɾ���ü�ֵ�Բ�ͬ��һϵ�й�ͬά���ı���
                        map(index,:) = [];
                        % ��Ӧ��MEC����������1(�ò�����λ�÷����˱仯�����Ĵ˴���Ҫ�޸�)
                        flags(min_j) = flags(min_j) + 1;
                        % ��J_s_matrix(min_i,min_j)��Ϊinf
                        J_s_matrix(min_i,min_j) = inf;
                    else
                        if min(J_s_matrix(min_i,:)) ~= inf
                            % �����ƶ��豸������ѡ�ķ�������ʱ�򣬲��������ҵ�����С���Ǹ�
                            % �˴�������Ҫ���䣡�ҵ���С���Ǹ�֮�󣬸���map�и��ƶ��豸ѡȡ�ķ������������Ƕ�Ӧ��Js��Сֵ
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