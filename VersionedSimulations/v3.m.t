%    the units we've decided to use are the same as in the Elias paper.
%Concentrations will be in micromolar (10^-6 mol/L. 1 mol = Avogadro?s # or 6.022*10^23 molecules) 
%and rate constants will likely be in min^-1. I say likely because they can take on different units,
%like M/min or M^-1*min^-1 depending on their order.
%function v3()
    % set plt = true to plot the graph
    plt = false;
    global single; single = true;
    %mutations
    global ARF_muta; ARF_muta = $boolean(.5),name=ARF_muta$;% 1 if ARF is not mutated otherwise 0

    %note for octave compatibility, must install odepkg for octave and also execute the following line
    %every session.
    %pkg load odepkg
    %Alternately, make a file called .octaverc in your home directory, and put that line in the file.
    %we'll have to verify that this works when calling octave through python.


    %ENTITIES in the model:
    %These are the proteins, mRNA, etc., each of which has an ODE describing its dynamics, which we store in a file
    %so we can re-use in the ODE function.
    run /Users/taylorsorenson/Desktop/MGH/DSPP/VersionedSimulations/variableDefinition3.m

    %Initial conditions
    x0 = zeros(numEntities,1);
    %here any non-zero initial conditions
    %for now, we we are modeling our radiation blast as an exponetially decaying level, we just initialize
    %the radiation compartment.
%     x0(P_Apoptosome) = 0;
%     x0(O_BROKEN_ENDS) = 0;
%     x0(O_CAPS) = 0;
%     x0(O_CAPPED_ENDS) = 0;
%     x0(O_CAPPED_ENDS_READY) = 0;
%     x0(O_FIXED) = 0;
%     x0(O_ARRESTSIGNAL) = 0; 
%     x0(P_Apoptosis)= 0;
if ARF_muta == 0
    x0(P_ARF) = 0.1;
end
    x0(O_CELLCYCLING) = 1;
	x0(P_ECDK2) = 1.5;
	x0(O_RADIATION) = 1;


    %Simulation time span. We will take the units of time to be MINUTES since that is what Elias paper uses.

    numDays=1;
    Tend_minutes = 24*60*numDays; %currently set for ___
                                      %simulation time.
    tspan=[0,Tend_minutes];

    %Just using these default values. They seem fine for now, we might find it useful to adjust later. I'm also using the
    %low order solver ode23. We may need to change this later too.
    opts = odeset('AbsTol',1e-3,'RelTol',1e-5,'MaxStep',6,'InitialStep',.1);
    [t,x]=ode23(@f,tspan,x0,opts);
    if plt == true
        subplot(1,3,1)
        varsToPlot = [2 5 P_Apaf1];
        plot(t/60,x(:,varsToPlot));
        xlabel('Time [hrs]');
        legend(N(varsToPlot));

        %here replicate stuff plotted in Elias figure 4.8

        subplot(1,3,2)
        varsToPlot = [P_CytC P_ECDK2 P_Apoptosome ];
        % varsToPlot = [P_CytC P_Apaf1 P_Apoptosome P_ECDK2 P_FasL];

        %varsToPlot = [P_Siah P_Reprimo];
        h=plot(t/60,x(:,varsToPlot));  
        xlabel('Time [hrs]');
        legend(N(varsToPlot));

        subplot(1,3,3)
        %varsToPlot = [P_ATMNucPhos P_P53NucPhos P_MDM2Nuc P_WIP1Nuc];
        varsToPlot = [O_CELLCYCLING O_ARRESTSIGNAL O_Apoptosis];
        h=plot(t/60,x(:,varsToPlot));
        xlabel('Time [hrs]');
        legend(N(varsToPlot));
        

        
    else
        %here display the output value we will do machine learning on. for
        %now I'll just use the final value of cell cycling. this will not
        %be what we use eventually, just a placeholder for now. put
        %plt to false to see this printed out.
        x(end,O_CELLCYCLING);
        output = 0;% if output is 0 then it mean we did not cover all the cases which it should not happen. 
        if max(x(:,O_Apoptosis)) >= 0.7%Apoptosis occurs
            output = 3;
        else
            if max(x(:,O_ARRESTSIGNAL))>= 0.7%cell arrest occurs
             output = 1;
            elseif  x(end,O_CELLCYCLING)>= 0.7% cell cycling 
               output = 2;
            else
                output = 4;%other
            end
        end
      disp(strcat('[',int2str(output),']'));     
        
    end

    function xd=f(t,x)

        %In this function we have the differential equations.

        %I'm hoping calling this script at every entrance to this function won't slow things
        %down too much. I don't think it will. If it does we might consider using globals or something like that.

        global single;
        global ARF_muta;
        run /Users/taylorsorenson/Desktop/MGH/DSPP/VersionedSimulations/variableDefinition3.m;

        %We start with all the parameters of those equations. We might want to think a little more
        %about an organized nomenclature for these. For example it would be nice to be able to tell from the name
        %basically what it is doing. But we also don't want to be cumbersome and have really long names (I think..).
        %So for now we will go with this but we might come up with a more refined standard.
        c_Kiri = .03;
        c_Kbe = .03;
        c_Kbec = $.003$; %decreasinging this to slow down repair process
        c_Kc = .02;
        c_Kcc = .01; %caps clearance rate/halflife term
        c_Mc = .01;
        c_Kcer = $uniform(.002,0.5),name=c_Kcer$;
        c_Kf = $uniform(0.001,0.02),name=c_Kf$;

        %next come constants from the Elias paper https://hal.inria.fr/hal-00822308/document
        ATMtot = 1.3; % total concentration of ATM proteins (monomers and dimers)
        %E = 2.5e-5; % signal produced by DNA damage [orig Elias model, I
        %their E in the paper was anything from  2.5e-5 to 10. can use the parameter Kph2 to do this scaling.

        %do it differently]
        % the system's constants, for the full description see Table B.1


        k3=3;
        Katm=$uniform(0.01,0.1),name=Katm$;
        kdph1=7800; %craft: changing this to see if i can get
                          %p53nucphos to taper out faster. orig
                          %value: 78
        Kdph1=$250$; %try this one too
        k1=10;
        K1=1.01;
        pp=0.083;
        Vr=10;
        pm=0.04;
        deltam=0.16;
        kSm=0.005;
        kSpm=1;
        KSpm=0.1;
        pmrna=$0.083$;
        deltamrna=0.0001;
        ktm=1;
        kS=0.015;
        deltap=0.2;
        pw=0.083;
        deltaw=0.2;
        kSw=0.03;
        kSpw=1;
        KSpw=0.1;
        pwrna=0.083;
        deltawrna=0.001;
        ktw=1;
        % this next one to modify the radiation impact:
        kph2=$uniform(15,150),name=kph2$;
        Kph2=1;

        kdph2=96;
        Kdph2=26;
        % nondimensionalisation of the variables is done so that the term relative to
        % the main bifurcation parameter E depends on as small possible number of
        % parameters as possible. Other choices are, of course, possible.
        %barE = E/Kph2;
        ts=1/kph2;
        alpha1=Katm; alpha4=alpha1; alpha2=kSpm/k3; alpha3=alpha2;
        alphav1=Kph2; alphav2=alphav1;
        alphaw1=kSpw/k3*10; alphaw2=alphaw1;
        barkdph1 = ts*kdph1*(alphaw1/alpha1); barKdph1 = Kdph1/alpha4;
        bark1 = ts*k1*(alpha2/alpha1); barK1 = K1/alpha1;

        bark3 = ts*k3*(alphav2/alpha1); barKatm = Katm/alpha1;
        barpp=ts*pp; barpm=ts*pm; bardeltam=ts*deltam;
        barkSm=ts*kSm/alpha3; barkSpm=ts*kSpm/alpha3; barKSpm=KSpm/alpha4;
        barpmrna=ts*pmrna; bardeltamrna=ts*deltamrna;
        barpw=ts*pw; bardeltaw=ts*deltaw;
        barkSw=ts*kSw/alphaw2; barkSpw=ts*kSpw/alphaw2; barKSpw=KSpw/alpha4;
        barpwrna=ts*pwrna; bardeltawrna=ts*deltawrna;
        barkdph2=ts*kdph2*(alphaw1/alphav2); barKdph2=Kdph2/(alphav2^2);
        barkS=ts*kS/alpha1; bardeltap=ts*deltap;
        barktm=ts*ktm; barktw=ts*ktw;
        ATMtot=ATMtot/alphav1;

        %Apoptosis Rate Constants --> p53 to Cyt c model

        c_KpB1 = $2$;
        c_KpB2 = $2$;%positive affect on cellcycling
        c_KpB3 = 0.5;
        c_KpBX1 = $2.5$;
        c_KpBX2 = $1.7$;
        c_KpBX3 = 0.4; %clearance term - slows if k > 2
        c_KpF1 = $1.5$; %affects apop reasonably if .1 < k < 10
        c_KpF2 = $2$; %affects apop reasonably if .01 < k < 5
        c_KpF3 = $0.2$; %clearance term - slows if k > 1, reasonably affects apop if 1 > k > .1
        c_KpBa1 = $2$;
        c_KpBa2 = 2;
        c_KpBa3 = $0.3$;%clearance term - slows if k > 1
        c_KBaxC1 = 1.3;
        c_KBaxC2 = 0.9;
        c_KBaxC3 = 1;
        c_KBcl2C1 = $1.3$;
        c_KBcl2C2 = $1.1$;
        c_KBcl2C3 = 1;
        c_KBclXC1 = $1.3$;
        c_KBclXC2 = $1$;
        c_KBclXC3 = 1;
        c_KCyt = 0.3;%clearence term
        c_Kapa1 = $2$;
        c_Kapa2 = 1;
        c_Kapa3 = 0.3;
        c_KAA = 0.7;
        c_KAA2 = 0.3;%clearance term - DOES NOT slow, does not affect cell fate
        c_KApop = $0.12$;%increase Apoptosis - apop changes reasonably if .1 < k < 10
        c_KApop2 = $0.11$;%increase Apoptosis maybe set this around 1 to make it resonalable
        c_KApop3 = $0.2$;%reasonable changes in apop if  .08 < k < 5
        c_Kpp1 = $0.3$;%sig changes in cc and arrest if 1 < k < 100
        c_Kpp2 = $0.6$;%sig changes in cc & arrest if .1 < k < 2
        c_Kpp3 = $0.2$;%slow clearance term if k > 2 AND affects cell cycling and arrest signal if <1
        c_KpE1 = $0.6$; %changes cc & arrest. .1 < k < 1
        c_KpE2 = $1.3$; %changes cc & arrest 1 < k < 20 
        c_KpE3 = $1$; %changes cc & arrest .1 < k < 1
        c_KpE4 = $0.4$;%
        K_Rb = $boolean(.5), name=K_Rb$;%1 <K_Rb < 28 affects cellcycling & arrestsignal symmetrically
        c_Ka1 = 4; %Cellcycling stops if >70; changes cc and arrest symmetrically;
        c_Ka2 = 0.8;% supress arrest signaling max 0.9 %Sig. changes in cc and arrest if 1 < k < 3
        Kg = 0.8;%Significant changes in cell cycling if 1 < Kg < 28
        K_MYC = $uniform(0.5,3),name=K_MYC$;
        c_E2F1 = 1; %clearance term - increases run time if k > 1
        c_ARF1 = 1.5;
        c_ARF2 = 2;
        c_ARF3 = 0.4; %clearance term - increases run time if k > 1
        c_MDM2Nuc1 = 1;
        c_MDM2Nuc2 = 1;
        c_Kps = 1;
        c_Kps2 = .1;
        c_si = 0.4; %clearance term -slows down run time if k > 1 
        c_Kpr = 1.8;
        c_Kpr2 = 3;
        c_re = 0.2;  %clearance term - slow if k > 1, no significant effect
        

        xd = zeros(numEntities,1);

        % the odes

        %DNA impact and repair kinetics
        xd(O_RADIATION) = -c_Kiri * x(O_RADIATION);
        xd(O_BROKEN_ENDS) = c_Kbe * x(O_RADIATION) - c_Kbec * x(O_BROKEN_ENDS) * x(O_CAPS);
        xd(O_CAPS) = min((c_Kc * x(O_BROKEN_ENDS)) ,c_Mc) - c_Kbec * x(O_BROKEN_ENDS) * x(O_CAPS) ...
                             - c_Kcc * x(O_CAPS);
        xd(O_CAPPED_ENDS) = c_Kbec * x(O_BROKEN_ENDS) * x(O_CAPS) -c_Kcer * x(O_CAPPED_ENDS);
        xd(O_CAPPED_ENDS_READY) = c_Kcer * x(O_CAPPED_ENDS) - c_Kf * x(O_CAPPED_ENDS_READY);
        xd(O_FIXED) = c_Kf * x(O_CAPPED_ENDS_READY);


        if single
            %Elias paper https://hal.inria.fr/hal-00822308/document
            % equations for single compartment model (C.1)
            % p53
            xd(P_P53Nuc) = barkS + barkdph1 * x(P_WIP1Nuc) * ((x(P_P53NucPhos)/(barKdph1+x(P_P53NucPhos)))) ...
                - bark1 * x(P_MDM2Nuc) * (x(P_P53Nuc)/(barK1+x(P_P53Nuc))) ...
                        -bark3 * x(P_ATMNucPhos) * (x(P_P53Nuc)/(barKatm+x(P_P53Nuc))) - deltap*(x(P_P53Nuc));
            % Mdm2
            xd(P_MDM2Nuc) = barktm * x(M_MDM2Nuc) - x(P_MDM2Nuc);
            % Mdm2 mRNA
            xd(M_MDM2Nuc) = barkSm + barkSpm * (x(P_P53NucPhos)^4/(barKSpm^4+x(P_P53NucPhos)^4)) - deltamrna * x(M_MDM2Nuc) ...
                        - barktm * x(M_MDM2Nuc);
            % p53_p
            xd(P_P53NucPhos) = bark3 * x(P_ATMNucPhos) * (x(P_P53Nuc)/(barKatm+x(P_P53Nuc))) - barkdph1*x(P_WIP1Nuc)*(x(P_P53NucPhos)/(barKdph1+x(P_P53NucPhos)));
            %Wip1
            xd(P_WIP1Nuc) = barktw * x(M_WIP1Nuc) - deltaw * x(P_WIP1Nuc);
            %Wip1 mRNA
            xd(M_WIP1Nuc) = barkSw + barkSpw * (x(P_P53NucPhos)^4/(barKSpw^4+x(P_P53NucPhos)^4)) - deltawrna * x(M_WIP1Nuc) ...
                        - barktw * x(M_WIP1Nuc);
            % Atm_p
            %here we are replacing their E with "broken ends": assuming
            %"danger signal" is proportional to number of broken ends:
            %xd(P_ATMPhos)=2*Kph2*0.1*( ((ATMtot-x(P_ATMPhos))/2)/(1+((ATMtot-x(P_ATMPhos))/2) )) -2*barkdph2*x(P_WIP1)*(x(P_ATMPhos)^2/(barKdph2+x(P_ATMPhos)^2));
            xd(P_ATMNucPhos) = 2*Kph2 * x(O_BROKEN_ENDS) * ((ATMtot- x(P_ATMNucPhos))/2)/(barKdph2 + ((ATMtot - x(P_ATMNucPhos))/2)) ...
                -2*barkdph2 * x(P_WIP1Nuc) * (x(P_ATMNucPhos)^2/(barKdph2 + x(P_ATMNucPhos)^2));

        else
            %Elias paper https://hal.inria.fr/hal-00822308/document
            % equations for the nucleus (B.1)
            % p53
            xd(P_P53Nuc) = barkdph1 * x(P_WIP1Nuc) * (x(P_P53NucPhos) / (barKdph1 + x(P_P53NucPhos)))- bark1 * x(P_MDM2Nuc) * (x(P_P53Nuc) / (barK1+x(P_P53Nuc))) ...
                        -bark3 * x(P_ATMNucPhos) * (x(P_P53Nuc) / (barKatm + x(P_P53Nuc))) - barpp * Vr * (x(P_P53Nuc) - x(P_P53Cyto));
            % Mdm2
            xd(P_MDM2Nuc) = -barpm * Vr * (x(P_MDM2Nuc) - x(P_MDM2Cyto)) - bardeltam * x(P_MDM2Nuc);
            % Mdm2 mRNA
            xd(M_MDM2Nuc) = barkSm + barkSpm * (x(P_P53NucPhos)^4 / (barKSpm^4 + x(P_P53NucPhos)^4)) - barpmrna * Vr * x(M_MDM2Nuc) ...
                        -bardeltamrna * x(M_MDM2Nuc);
            % p53_p
            xd(P_P53NucPhos) = bark3 * x(P_ATMNucPhos) * (x(P_P53Nuc) / (barKatm + x(P_P53Nuc))) - barkdph1 * x(P_WIP1Nuc) * (x(P_P53NucPhos) / (barKdph1 + x(P_P53NucPhos)));
            %Wip1
            xd(P_WIP1Nuc) = barpw * Vr * x(P_WIP1Cyto) - bardeltaw * x(P_WIP1Nuc);
            %Wip1 mRNA
            xd(M_WIP1Nuc)= barkSw + barkSpw * (x(P_P53NucPhos)^4 / (barKSpw^4 + x(P_P53NucPhos)^4)) -barpwrna * Vr * x(M_WIP1Nuc) ...
                        -bardeltawrna * x(M_WIP1Nuc);
            % Atm_p
            %here we are replacing their E with "broken ends": assuming
            %"danger signal" is proportional to number of broken ends:
            %xd(P_ATMNucPhos)=2*Kph2*0.1*( ((ATMtot-x(P_ATMNucPhos))/2)/(1+((ATMtot-x(P_ATMNucPhos))/2) )) -2*barkdph2*x(P_WIP1Nuc)*(x(P_ATMNucPhos)^2/(barKdph2+x(P_ATMNucPhos)^2));
            xd(P_ATMNucPhos) = 2 * Kph2 * x(O_BROKEN_ENDS) * (((ATMtot - x(P_ATMNucPhos)) / 2) / (1 + ((ATMtot - x(P_ATMNucPhos))/2))) - 2 * barkdph2 * x(P_WIP1Nuc) * (x(P_ATMNucPhos)^2 / (barKdph2 + x(P_ATMNucPhos)^2));


            % equations for the cytoplasm (B.2)
            % p53
            xd(P_P53Cyto) = barkS - bark1 * x(P_MDM2Cyto) * (x(P_P53Cyto) / (barK1 + x(P_P53Cyto))) - bardeltap * x(P_P53Cyto) - barpp * (x(P_P53Cyto) - x(P_P53Nuc));
            % Mdm2
            xd(P_MDM2Cyto) = barktm * x(M_MDM2Cyto) - barpm * (x(P_MDM2Cyto)-x(P_MDM2Nuc)) - bardeltam * x(P_MDM2Cyto);
            % Mdm2 mRNA
            xd(M_MDM2Cyto) = barpmrna * x(M_MDM2Nuc) - barktm * x(M_MDM2Cyto) - bardeltamrna * x(M_MDM2Cyto);
            % Wip1
            xd(P_WIP1Cyto) = barktw * x(M_WIP1Cyto) - barpw * x(P_WIP1Cyto) - bardeltaw * x(P_WIP1Cyto);
            % Wip1 mRNA
            xd(M_WIP1Cyto) = barpwrna * x(M_WIP1Nuc) - barktw * x(M_WIP1Cyto) - bardeltawrna * x(M_WIP1Cyto);

        end

        %Apoptosis Pathways
        %and apoptosome
        %BCl-2
        xd(P_Bcl2) = c_KpB1*(x(P_P53NucPhos)^4)/(c_KpB2 + x(P_P53NucPhos)^4) - c_KpB3 * x(P_Bcl2);
        %Bcl-Xl
        xd(P_BclXl) = c_KpBX1*(x(P_P53NucPhos)^4)/(c_KpBX2 + x(P_P53NucPhos)^4) - c_KpBX3 * x(P_BclXl);
        %Fas-l
        xd(P_FasL) = c_KpF1*(x(P_P53NucPhos)^4)/(c_KpF2 + x(P_P53NucPhos)^4) - c_KpF3 * x(P_FasL);
        %BAX
        xd(P_Bax) = c_KpBa1*(x(P_P53NucPhos)^4)/(c_KpBa2 + x(P_P53NucPhos)^4) - c_KpBa3 * x(P_Bax);
        %Apaf1
        xd(P_Apaf1) = c_Kapa1*(x(P_P53NucPhos)^4)/(c_Kapa2 + x(P_P53NucPhos)^4) - c_Kapa3 * x(P_Apaf1);
        %Cytochrome c
        xd(P_CytC) = (c_KBaxC1/(1+ exp(-c_KBaxC2*(x(P_Bax)- c_KBaxC3)))) * ...
            c_KBcl2C1 * (1 - 1/(1+ exp(-c_KBcl2C2*(x(P_Bcl2)- c_KBcl2C3)))) * ...
            c_KBclXC1 * (1 - 1/(1+ exp(-c_KBclXC2*(x(P_BclXl)- c_KBclXC3)))) - c_KCyt*(x(P_CytC)) ...
           - c_KAA*x(P_Apaf1)*x(P_CytC)^7;
        %Apoptosome
        xd(P_Apoptosome) = c_KAA*x(P_Apaf1)*x(P_CytC)^7 - c_KAA2 *x(P_Apoptosome);
        %Apoptosis
        xd(O_Apoptosis) = c_KApop*x(P_FasL) + c_KApop2 * x(P_Apoptosome) - c_KApop3 * x(O_Apoptosis);

        %MYC --> p53
        %E2F later on we might model E2F from  
        %Dong,P. et al. Division of labour between Myc and G1 cyclins in cell cycle commitment and pace control. Nat. Commun. 5:4750 doi: 10.1038/ncomms5750 (2014). 
        %website: https://www.nature.com/articles/ncomms5750
        xd(P_E2F) = K_Rb*K_MYC - c_E2F1*x(P_E2F);
        %ARF
        
        xd(P_ARF) =ARF_muta*( c_ARF1 * (x(P_E2F)/(c_ARF2+x(P_E2F))) - c_ARF3 * x(P_ARF));
        


        %Cell cycle arrest modules --> p53 -- p21cip -- ECDK2 --pRb
        %p21cip
        xd(P_p21cip) = c_Kpp1*(x(P_P53NucPhos)^4)/(c_Kpp2 + x(P_P53NucPhos)^4) - c_Kpp3 * x(P_p21cip);
        %ECDK2
        xd(P_ECDK2) = c_KpE1 - c_KpE2*x(P_p21cip)/(c_KpE3 + x(P_p21cip)) - c_KpE4 * x(P_ECDK2);
        %Cell Cycle Arrest Important Note: Arrest Signal equation found by taking 
        %the derivative of the inverse sigmoid function.
        %Other note: kRb should either be on or off (represents gene)
        xd(O_ARRESTSIGNAL) = (-K_Rb*c_Ka1*xd(P_ECDK2)*exp(-c_Ka1*(x(P_ECDK2)- c_Ka2)))/ ...
            (1+ exp(-c_Ka1*(x(P_ECDK2)- c_Ka2)))^2;
        %Cell Cycling, Note: Kg represents growth constant
        xd(O_CELLCYCLING) = -Kg*xd(O_ARRESTSIGNAL);
        %Siah
        xd(P_Siah) = c_Kps*(x(P_P53NucPhos)^4)/(c_Kps2 + x(P_P53NucPhos)^4) - c_si * x(P_Siah);
        %Reprimo
        xd(P_Reprimo) = c_Kpr*(x(P_P53NucPhos)^4)/(c_Kpr2 + x(P_P53NucPhos)^4) - c_re * x(P_Reprimo);
        end
