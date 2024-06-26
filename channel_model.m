clc 
clear all

Na = 10;
snr_dB=0:1:8;
snr_linear = 10.^(snr_dB/10);
a = zeros(1,Na);
msg = (-1+2*randi([0,1],1,Na));
nErrs = zeros(1,length(snr_linear));

beta = 0.3; %%rolloff factor
tau = 0.8;
span = 20; %%sps * Span must be even
sps = 100; %%Samples per symbol, Modulation scheme value
h = rcosdesign(beta,span,sps,'normal');
h= h/ max(h);
if floor(round(sps * tau)) ~= ceil(round(sps * tau)) % Check if ns*tau is an integer %%checks if symbol duration is for nT where n is an integer
    error('ns*tau must be an integer') %%floor rounds down, ceil rounds up. Only solution for this is to have int. Zichao is checking for nT
end
zzz = sps * span / 2 + 1; %%calculates index at center of sinc
ind = 0:round(tau * sps):min(round(tau * sps) * (Na - 1), sps * span / 2);
G = toeplitz([h(zzz + ind), zeros(1, Na - length(ind))], ...
    [h(zzz - ind), zeros(1, Na - length(ind))]);
% G_inv = inv(G);
h(1:tau*sps:end);
Pa=1/2*ones(Na,1)'; 
Noise = randn([Na,1]);
G_k=[];
Rn = eye(Na);
D_k = zeros(1,length(Na));
%%Preallocating a and a_curr;
a = zeros(1,Na);
a_curr = zeros(1,Na);

%%Preallocating y, note that y is a vector but stored in a bigger array due
%%to several SNR, reference this only using y(:,i)
y = zeros(Na,length(snr_linear));

%%iteration number
iter = 5;
f_ind=1:Na;
for i = 1 : length(snr_linear)
    a_curr = snr_linear(i)*msg;
    % y = G.*a_curr;
    a(a_curr < 0) = -1;
    a(a_curr >=0) = 1;
    a = a';
    y(:,i) = G*a_curr' + Noise;
    % big_y = [big_y y];
    fprintf("Transmitted message %s for SNR %s dB\n",sprintf('%d ',a),sprintf('%d',snr_dB(i)));

    for j=1:iter
        u_idx = f_ind;
        [D_k,~,~,~] = compute_Dk(G,Pa,f_ind,Rn);
        while ~isempty(u_idx)
            [~,k_m] = max(D_k);
            [~,mew_k,C_k,g_k]=compute_Dk(G,Pa,u_idx(k_m),Rn);
            Pa(u_idx(k_m)) = 1/(1+exp(-2*(y(:,i)-mew_k)' * inv(C_k) * g_k));%%U_IDX CHANGES BUT K_M DOES NOT CHANGE
            u_idx(k_m) = [];
            if isempty(u_idx)
                break
            end
            [D_k,~,~,~] = compute_Dk(G,Pa,u_idx,Rn);
            % [~,~,~,~,expected_ak] = compute_Dk(G,Pa,u_idx,Rn);

        end
    end
    a_hat =sign(-0.5+Pa);

    BER_AWGN(i) = qfunc(sqrt(2*snr_linear(i)));
    BER_FTN(i) = qfunc(sqrt(2*tau*snr_linear(i)));
    BER_tao(i) = qfunc(sqrt(2*0.9*snr_linear(i)));
    fprintf("Received message is %s at SNR %s dB\n",sprintf('%d ',a_hat),sprintf('%d',snr_dB(i)));
end
figure(1)
semilogy(snr_dB,BER_AWGN,'k');
hold on
semilogy(snr_dB,BER_FTN,'r');
semilogy(snr_dB,BER_tao,'m');
grid on
hold off
legend('Zero ISI - τ = 1','Proposed PDA: τ = 0.8','Proposed PDA: τ = 0.9');
return

function [D_k,mew_k,C_k,g_k] = compute_Dk(G,Pa,f_ind,Rn)
    for k =1:length(f_ind)
    % k = 1:1:Na;
        G_a=G;
        G_a(:,f_ind(k))=[];
        % G_k = [G_k G_a];
        %disp(G_a);
        % C_ak = ones(1,Na-1);
    
    
        g_k=G(:,f_ind(k));
        %disp(g_k);
        Pa_k = Pa;
        Pa_k(f_ind(k))=[];
        C_ak=4*diag(Pa_k)*diag(1-Pa_k);
        C_k=G_a*C_ak*G_a'+Rn;
        D_k(k)=g_k'*inv(C_k)*g_k;

        expected_ak = 2*Pa_k-1;
        mew_k(:,k) = G_a * expected_ak' ;
       
    end

  
end


