function DelayLaw = EvalDelayLaw( X_mm , Z_mm  )
%creation of function 11/09/2017 for delay law retreival using sequence
%parameters. 
% ct = M0 M(t)
Nangle = size(Z_mm , 1) ;
% 0 is defined by the (0,0) on probe linear plane

  Hf = figure;
  set(Hf,'WindowStyle','docked');
  subplot(211)
    cc = jet(Nangle);
    for i = 1:Nangle     
       hold on
       angle(i) = atan( (Z_mm(i,1)-Z_mm(i,end))/(X_mm(end) - X_mm(1)) );
       % definition ut vector :
       ut(i,:)= [sin(angle(i)) , cos(angle(i))] ; % (x,z)
       plot( X_mm , Z_mm(i,:) ,'linewidth',3,'color',cc(i,:)) 
    end
    cb = colorbar ;
    ylabel(cb,'angular index')
    xlabel('X (mm)')
    ylabel('Z(mm)')
    set(gca,'YDir','reverse')
    
subplot(212)
plot(180/pi*angle,'-o','linewidth',3)
xlabel('shoot index')
xlabel('angle (�)')
    








DelayLaw = 0 ;

end

