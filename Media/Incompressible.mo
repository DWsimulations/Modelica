package Incompressible 
  "Medium model for T-dependent properties, defined by tables or polynomials" 
  
  import SI = Modelica.SIunits;
  import Cv = Modelica.SIunits.Conversions;
  import Modelica.Constants;
  import Modelica.Math;
  
  package Common 
    
    // Extended record for input to functions based on polynomials
    record BaseProps_Tpoly "fluid state record" 
      extends Modelica.Media.Interfaces.PartialMedium.ThermodynamicState;
      //      SI.SpecificHeatCapacity cp "specific heat capacity";
      SI.Temperature T "temperature";
      SI.Pressure p "pressure";
      //    SI.Density d "density";
    end BaseProps_Tpoly;
    
    record BaseProps_Tpoly_old "fluid state record" 
      extends Modelica.Media.Interfaces.PartialMedium.ThermodynamicState;
      //      SI.SpecificHeatCapacity cp "specific heat capacity";
      SI.Temperature T "temperature";
      SI.Pressure p "pressure";
      //    SI.Density d "density";
      parameter Real[:] poly_rho "polynomial coefficients";
      parameter Real[:] poly_Cp "polynomial coefficients";
      parameter Real[:] poly_eta "polynomial coefficients";
      parameter Real[:] poly_pVap "polynomial coefficients";
      parameter Real[:] poly_lam "polynomial coefficients";
      parameter Real[:] invTK "inverse T [1/K]";
    end BaseProps_Tpoly_old;
  end Common;
  
  package TableBased "Incompressible medium properties based on tables" 
    
    import Poly = Modelica.Media.Incompressible.TableBased.Polynomials_Temp;
    
    extends Modelica.Media.Interfaces.PartialMedium(
       final reducedX=true,
       mediumName="tableMedium",
       redeclare record ThermodynamicState=Common.BaseProps_Tpoly,
       singleState=true);
    // Constants to be set in actual Medium
    constant Boolean enthalpyOfT=true 
      "true if enthalpy is approximated as a function of T only, (p-dependence neglected)";
    constant Boolean densityOfT = size(tableDensity,1) > 1 
      "true if density is a function of temperature";
    constant Temperature T_min "Minimum temperature valid for medium model";
    constant Temperature T_max "Maximum temperature valid for medium model";
    constant Temperature T0=273.15 "reference Temperature";
    constant SpecificEnthalpy h0=0 "reference enthalpy at T0, reference_p";
    constant SpecificEntropy s0=0 "reference entropy at T0, reference_p";
    constant MolarMass MM_const=0.1 "Molar mass";
    constant Integer npol=2 "degree of polynomial used for fitting";
    constant Integer neta=size(tableViscosity,1) 
      "number of data points for viscosity";
    constant Real[:,:] tableDensity "Table for rho(T)";
    constant Real[:,:] tableHeatCapacity "Table for Cp(T)";
    constant Real[:,:] tableViscosity "Table for eta(T)";
    constant Real[:,:] tableVaporPressure "Table for pVap(T)";
    constant Real[:,:] tableConductivity "Table for lambda(T)";
    //    constant Real[:] TK=tableViscosity[:,1]+T0*ones(neta) "Temperature for Viscosity";
    constant Boolean TinK "true if T[K],Kelvin used for table temperatures";
    constant Boolean hasDensity = not (size(tableDensity,1)==0);
    constant Boolean hasHeatCapacity = not (size(tableHeatCapacity,1)==0);
    constant Boolean hasViscosity = not (size(tableViscosity,1)==0);
    constant Boolean hasVaporPressure = not (size(tableVaporPressure,1)==0);
    
    final constant Real invTK[neta] = {1/(if TinK then tableViscosity[i,1] else Cv.from_degC(tableViscosity[i,1])) for i in 1:neta};
    final constant Real poly_rho[:] = if hasDensity then 
                                         Poly.fitting(tableDensity[:,1],tableDensity[:,2],npol) else 
                                           zeros(npol+1);
    final constant Real poly_Cp[:] = if hasHeatCapacity then 
                                         Poly.fitting(tableHeatCapacity[:,1],tableHeatCapacity[:,2],npol) else 
                                           zeros(npol+1);
    final constant Real poly_eta[:] = if hasViscosity then 
                                         Poly.fitting(invTK, Math.log(tableViscosity[:,2]),npol) else 
                                           zeros(npol+1);
    final constant Real poly_pVap[:] = if hasVaporPressure then 
                                         Poly.fitting(tableVaporPressure[:,1],tableVaporPressure[:,2],npol) else 
                                            zeros(npol+1);
    final constant Real poly_lam[:] = if size(tableConductivity,1)>0 then 
                                         Poly.fitting(tableConductivity[:,1],tableConductivity[:,2],npol) else 
                                           zeros(npol+1);
    
    redeclare model extends BaseProperties(
      R=Modelica.Constants.R,
      p_bar=Cv.to_bar(p),
      T_degC(start = T_start-273.15)=Cv.to_degC(T),
      T(start = T_start,
        stateSelect=if preferredMediumStates then StateSelect.prefer else StateSelect.default)) 
      "Base properties of T dependent medium" 
      
      annotation(Documentation(info="
			       Note that the inner energy neglects the pressure dependence, which is only
			       true for an incompressible medium with d = constant. The neglected term is
			       (p-reference_p)/rho*(T/rho)*(partial rho /partial T). This is very small for
			       liquids due to proportionality to 1/d^2, but can be problematic for gases that are
			       modeled incompressible.
			       
			       Enthalpy is never a function of T only (h = h(T) + (p-reference_p)/d), but the
			       error is also small and non-linear systems can be avoided. In particular,
			       non-linear systems are small and local as opposed to large and over all volumes.
			       
			       Entropy is calculated as
  s = s0 + integral(Cp(T)/T,dt)
which is only exactly true for a fluid with constant density d=d0.
      "));
      SI.SpecificHeatCapacity cp "specific heat capacity";
      parameter SI.Temperature T_start = 298.15 "initial temperature";
    equation 
      assert(hasDensity,"Medium " + mediumName +
                        " can not be used without assigning tableDensity.");
      assert(T >= T_min and T <= T_max, "Temperature T (= " + String(T) +
             " K) is not in the allowed range (" + String(T_min) +
             " K <= T <= " + String(T_max) + " K) required from medium model \""
             + mediumName + "\".");
      cp = Poly.evaluate(poly_Cp,if TinK then T else T_degC);
      if enthalpyOfT then
         h = h_T(T);
      else
         h = h_pT(p,T,densityOfT);
      end if;
      
      if singleState then
         u = h_T(T) - reference_p/d;
      else
         u = h - p/d;
      end if;
      d = Poly.evaluate(poly_rho,if TinK then T else T_degC);
      state.T = T;
      state.p = p;
      MM = MM_const;
    end BaseProperties;
    
    redeclare function extends setState "Returns state record" 
      input SI.Pressure p "Pressure";
      input SI.Temperature T "Temperature";
    algorithm 
      state.p :=p;
      state.T :=T;
    end setState;
    
    redeclare function extends heatCapacity_cv 
      "Specific heat capacity at constant volume (or pressure) of medium" 
    algorithm 
      assert(hasHeatCapacity,"Specific Heat Capacity, Cv, is not defined for medium "
                                             + mediumName + ".");
      cv := Poly.evaluate(poly_Cp,if TinK then state.T else state.T - 273.15);
    end heatCapacity_cv;
    
    redeclare function extends heatCapacity_cp 
      "Specific heat capacity at constant volume (or pressure) of medium" 
    algorithm 
      assert(hasHeatCapacity,"Specific Heat Capacity, Cv, is not defined for medium "
                                             + mediumName + ".");
      cp := Poly.evaluate(poly_Cp,if TinK then state.T else state.T - 273.15);
    end heatCapacity_cp;
    
    redeclare function extends dynamicViscosity 
    algorithm 
      assert(size(tableViscosity,1)>0,"DynamicViscosity, eta, is not defined for medium "
                                             + mediumName + ".");
      eta := Math.exp(Poly.evaluate(poly_eta, 1/state.T));
    end dynamicViscosity;
    
    redeclare function extends thermalConductivity 
    algorithm 
      assert(size(tableConductivity,1)>0,"ThermalConductivity, lambda, is not defined for medium "
                                             + mediumName + ".");
      lambda := Poly.evaluate(poly_lam,if TinK then state.T else Cv.to_degC(state.T));
    end thermalConductivity;
    
    redeclare function extends specificEntropy 
    protected 
      Integer npol=size(poly_Cp,1)-1;
    algorithm 
      assert(hasHeatCapacity,"Specific Entropy, s(T), is not defined for medium "
                                             + mediumName + ".");
      s := s0 + (if TinK then 
        Poly.integralValue(poly_Cp[1:npol],state.T, T0) else 
        Poly.integralValue(poly_Cp[1:npol],Cv.to_degC(state.T),Cv.to_degC(T0)))
        + Modelica.Math.log(state.T/T0)*
        Poly.evaluate(poly_Cp,if TinK then 0 else Modelica.Constants.T_zero);
    end specificEntropy;
    
    function h_T "Compute specific enthalpy from temperature" 
      import Modelica.SIunits.Conversions.to_degC;
      extends Modelica.Icons.Function;
      input SI.Temperature T "Temperature";
      output SI.SpecificEnthalpy h "Specific enthalpy at p, T";
    algorithm 
      h :=h0 + Poly.integralValue(poly_Cp, if TinK then T else to_degC(T), if TinK then 
      T0 else to_degC(T0));
    end h_T;
    
    function h_pT "Compute specific enthalpy from pressure and temperature" 
      import Modelica.SIunits.Conversions.to_degC;
      extends Modelica.Icons.Function;
      input SI.Pressure p "Pressure";
      input SI.Temperature T "Temperature";
      input Boolean densityOfT = false 
        "include or neglect density derivative dependence of enthalpy" annotation(Evaluate);
      output SI.SpecificEnthalpy h "Specific enthalpy at p, T";
      annotation(Inline = false);
    algorithm 
      h :=h0 + Poly.integralValue(poly_Cp, if TinK then T else to_degC(T), if TinK then 
      T0 else to_degC(T0)) + (p - reference_p)/Poly.evaluate(poly_rho, if TinK then 
              T else to_degC(T))
        *(if densityOfT then (1 + T/Poly.evaluate(poly_rho, if TinK then T else to_degC(T))
      *Poly.derivativeValue(poly_rho,if TinK then T else to_degC(T))) else 1.0);
    end h_pT;
    
    package Polynomials_Temp 
      "Temporary Functions operating on polynomials (including polynomial fitting); only to be used in Modelica.Media.Incompressible.TableBased" 
      extends Modelica.Icons.Library;
      
      annotation (Documentation(info="<HTML>
<p>
This package contains functions to operate on polynomials,
in particular to determine the derivative and the integral
of a polynomial and to use a polynomial to fit a given set
of data points.
</p>
<p>
<p><b>Copyright (C) 2004, Modelica Association and DLR.</b></p>
<p><i>
This package is <b>free</b> software. It can be redistributed and/or modified
under the terms of the <b>Modelica license</b>, see the license conditions
and the accompanying <b>disclaimer</b> in the documentation of package
Modelica in file \"Modelica/package.mo\".
</i></p>
</HTML>
",     revisions="<html>
<ul>
<li><i>Oct. 22, 2004</i> by Martin Otter (DLR):<br>
       Renamed functions to not have abbrevations.<br>
       Based fitting on LAPACK<br>
       New function to return the polynomial of an indefinite integral<li>
<li><i>Sept. 3, 2004</i> by Jonas Eborn (Scynamics):<br>
       polyderval, polyintval added<li>
<li><i>March 1, 2004</i> by Martin Otter (DLR):<br>
       first version implemented
</li>
</ul>
</html>"),     uses(Modelica(version="2.1"), Modelica_Interpolation(version="0.94")));
      function evaluate "Evaluate polynomial at a given abszissa value" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        output Real y "Value of polynomial at u";
        annotation(derivative(noDerivative=p)=evaluate_der);
      algorithm 
        y := p[1];
        for j in 2:size(p, 1) loop
          y := p[j] + u*y;
        end for;
      end evaluate;
      
      function derivative "Derivative of polynomial" 
        extends Modelica.Icons.Function;
        input Real p1[:] 
          "Polynomial coefficients (p1[1] is coefficient of highest power)";
        output Real p2[size(p1, 1) - 1] "Derivative of polynomial p1";
      protected 
        Integer n=size(p1, 1);
      algorithm 
        for j in 1:n-1 loop
          p2[j] := p1[j]*(n - j);
        end for;
      end derivative;
      
      function derivativeValue 
        "Value of derivative of polynomial at abszissa value u" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        output Real y "Value of derivative of polynomial at u";
        annotation(derivative(noDerivative=p)=derivativeValue_der);
      protected 
        Integer n=size(p, 1);
      algorithm 
        y := p[1]*(n - 1);
        for j in 2:size(p, 1)-1 loop
          y := p[j]*(n - j) + u*y;
        end for;
      end derivativeValue;
      
      function secondDerivativeValue 
        "Value of 2nd derivative of polynomial at abszissa value u" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        output Real y "Value of 2nd derivative of polynomial at u";
      protected 
        Integer n=size(p, 1);
      algorithm 
        y := p[1]*(n - 1)*(n - 2);
        for j in 2:size(p, 1)-2 loop
          y := p[j]*(n - j)*(n - j - 1) + u*y;
        end for;
      end secondDerivativeValue;
      
      function integral "Indefinite integral of polynomial p(u)" 
        extends Modelica.Icons.Function;
        input Real p1[:] 
          "Polynomial coefficients (p1[1] is coefficient of highest power)";
        output Real p2[size(p1, 1) + 1] 
          "Polynomial coefficients of indefinite integral of polynomial p1 (polynomial p2 + C is the indefinite integral of p1, where C is an arbitrary constant)";
      protected 
        Integer n=size(p1, 1) + 1 "degree of output polynomial";
      algorithm 
        for j in 1:n-1 loop
          p2[j] := p1[j]/(n-j);
        end for;
      end integral;
      
      function integralValue "Integral of polynomial p(u) from u_low to u_high" 
        extends Modelica.Icons.Function;
        input Real p[:] "Polynomial coefficients";
        input Real u_high "High integrand value";
        input Real u_low=0 "Low integrand value, default 0";
        output Real integral=0.0 
          "Integral of polynomial p from u_low to u_high";
        annotation(derivative(noDerivative=p)=integralValue_der);
      protected 
        Integer n=size(p, 1) "degree of integrated polynomial";
        Real y_low=0 "value at lower integrand";
      algorithm 
        for j in 1:n loop
          integral := u_high*(p[j]/(n - j + 1) + integral);
          y_low := u_low*(p[j]/(n - j + 1) + y_low);
        end for;
        integral := integral - y_low;
      end integralValue;
      
      function fitting 
        "Computes the coefficients of a polynomial that fits a set of data points in a least-squares sense" 
        extends Modelica.Icons.Function;
        input Real u[:] "Abscissa data values";
        input Real y[size(u, 1)] "Ordinate data values";
        input Integer n(min=1) 
          "Order of desired polynomial that fits the data points (u,y)";
        output Real p[n + 1] 
          "Polynomial coefficients of polynomial that fits the date points";
        annotation (Documentation(info="<HTML>
<p>
Polynomials.fitting(u,y,n) computes the coefficients of a polynomial
p(u) of degree \"n\" that fits the data \"p(u[i]) - y[i]\"
in a least squares sense. The polynomial is
returned as a vector p[n+1] that has the following definition:
</p>
<pre>
  p(u) = p[1]*u^n + p[2]*u^(n-1) + ... + p[n]*u + p[n+1];
</pre>
</HTML>"));
      protected 
        Real V[size(u, 1), n + 1] "Vandermonde matrix";
      algorithm 
        // Construct Vandermonde matrix
        V[:, n + 1] := ones(size(u, 1));
        for j in n:-1:1 loop
          V[:, j] := {u[i] * V[i, j + 1] for i in 1:size(u,1)};
        end for;
        
        // Solve least squares problem
        p :=Modelica.Math.Matrices.leastSquares(V, y);
      end fitting;
      
      function evaluate_der "Evaluate polynomial at a given abszissa value" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        input Real du "Abszissa value";
        output Real dy "Value of polynomial at u";
      protected 
        Integer n=size(p, 1);
      algorithm 
        dy := p[1]*(n - 1);
        for j in 2:size(p, 1)-1 loop
          dy := p[j]*(n - j) + u*dy;
        end for;
        dy := dy*du;
      end evaluate_der;
      
      function integralValue_der 
        "time derivative of integral of polynomial p(u) from u_low to u_high, assuming only u_high as time-dependent (Leibnitz rule)" 
        extends Modelica.Icons.Function;
        input Real p[:] "Polynomial coefficients";
        input Real u_high "High integrand value";
        input Real u_low=0 "Low integrand value, default 0";
        input Real du_high "High integrand value";
        input Real du_low=0 "Low integrand value, default 0";
        output Real dintegral=0.0 
          "Integral of polynomial p from u_low to u_high";
      algorithm 
        dintegral := evaluate(p,u_high)*du_high;
      end integralValue_der;
      
      function derivativeValue_der 
        "time derivative of derivative of polynomial" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        input Real du "delta of abszissa value";
        output Real dy 
          "time-derivative of derivative of polynomial w.r.t. input variable at u";
      protected 
        Integer n=size(p, 1);
      algorithm 
        dy := secondDerivativeValue(p,u)*du;
      end derivativeValue_der;
    end Polynomials_Temp;
    
  end TableBased;
  
  package Examples 
    
  package Glycol47 "1,2-Propylene glycol, 47% mixture with water" 
    extends TableBased(
      mediumName="Glycol-Water 47%",
      T_min = Cv.from_degC(-30), T_max = Cv.from_degC(100),
      TinK = false, T0=273.15,
      tableDensity=
        [-30, 1066; -20, 1062; -10, 1058; 0, 1054;
         20, 1044; 40, 1030; 60, 1015; 80, 999; 100, 984],
      tableHeatCapacity=
        [-30, 3450; -20, 3490; -10, 3520; 0, 3560;
         20, 3620; 40, 3690; 60, 3760; 80, 3820; 100, 3890],
      tableConductivity=
        [-30,0.397;  -20,0.396;  -10,0.395;  0,0.395;
         20,0.394;  40,0.393;  60,0.392;  80,0.391;  100,0.390],
      tableViscosity=
        [-30, 0.160; -20, 0.0743; -10, 0.0317; 0, 0.0190;
         20, 0.00626; 40, 0.00299; 60, 0.00162; 80, 0.00110; 100, 0.00081],
      tableVaporPressure=
        [0, 500; 20, 1.9e3; 40, 5.3e3; 60, 16e3; 80, 37e3; 100, 80e3]);
      //        [-30, 0.160; -20, 0.0743; -10, 0.0317;
      //  Low temperature points excluded to avoid bad fit with neta=3
  end Glycol47;
    
  package Essotherm650 "Essotherm thermal oil" 
    extends TableBased(
      mediumName="Essotherm 650",
      T_min = Cv.from_degC(0), T_max = Cv.from_degC(320),
      TinK = false, T0=273.15,
      tableDensity=
        [0, 909; 20, 897; 40, 884; 60, 871; 80, 859; 100, 846;
         150, 813; 200, 781; 250, 748; 300, 715; 320, 702],
      tableHeatCapacity=
        [0, 1770; 20, 1850; 40, 1920; 60, 1990; 80, 2060; 100, 2130;
         150, 2310; 200, 2490; 250, 2670; 300, 2850; 320, 2920],
      tableConductivity=
        [0,0.1302;  20,0.1288;  40,0.1274;  60,0.1260;  80,0.1246;  100,0.1232;
         150,0.1197;  200,0.1163;  250,0.1128;  300,0.1093;  320,0.1079],
      tableViscosity = [0, 14370; 20, 1917; 40, 424; 60, 134; 80, 54.5;
         100, 26.64; 150, 7.47; 200, 3.22; 250, 1.76; 300, 1.10; 320,0.94],
      tableVaporPressure=
        [160, 3; 180, 10; 200, 40; 220, 100; 240, 300; 260, 600;
         280, 1600; 300, 3e3; 320, 5.5e3]);
      //        [0, 14370; 20, 1917; 40, 424; 60, 134; 80, 54.5;
      //  Low temperature points excluded to avoid bad fit with neta=3
  end Essotherm650;
    
  model TestGlycol "Test Glycol47 Medium model" 
    extends Modelica.Icons.Example;
    package Medium = Glycol47;
    extends Medium.BaseProperties;
      
    Medium.DynamicViscosity eta=Medium.dynamicViscosity(state);
    Medium.ThermalConductivity lambda=Medium.thermalConductivity(state);
    Medium.SpecificEntropy s=Medium.specificEntropy(state);
    Medium.SpecificHeatCapacity cv=Medium.heatCapacity_cv(state);
  equation 
    p = 1e5;
    T = Medium.T_min + time;
  end TestGlycol;
    
  package Glycol47_old "1,2-Propylene glycol, 47% mixture with water" 
    extends TableBased_old(
      mediumName="Glycol-Water 47%",
      T_min = Cv.from_degC(-30), T_max = Cv.from_degC(100),
      TinK = false, T0=273.15,
      tableDensity=
        [-30, 1066; -20, 1062; -10, 1058; 0, 1054;
         20, 1044; 40, 1030; 60, 1015; 80, 999; 100, 984],
      tableHeatCapacity=
        [-30, 3450; -20, 3490; -10, 3520; 0, 3560;
         20, 3620; 40, 3690; 60, 3760; 80, 3820; 100, 3890],
      tableConductivity=
        [-30,0.397;  -20,0.396;  -10,0.395;  0,0.395;
         20,0.394;  40,0.393;  60,0.392;  80,0.391;  100,0.390],
      tableViscosity=
        [-30, 0.160; -20, 0.0743; -10, 0.0317; 0, 0.0190;
         20, 0.00626; 40, 0.00299; 60, 0.00162; 80, 0.00110; 100, 0.00081],
      tableVaporPressure=
        [0, 500; 20, 1.9e3; 40, 5.3e3; 60, 16e3; 80, 37e3; 100, 80e3]);
      //        [-30, 0.160; -20, 0.0743; -10, 0.0317;
      //  Low temperature points excluded to avoid bad fit with neta=3
  end Glycol47_old;
  end Examples;
  
  package TableBased_old "Incompressible medium properties based on tables" 
    
    import Poly = Modelica.Media.Incompressible.TableBased_old.Polynomials_Temp;
    
    extends Modelica.Media.Interfaces.PartialMedium(
       final reducedX=true,
       mediumName="tableMedium",
       redeclare record ThermodynamicState=Common.BaseProps_Tpoly_old,
  singleState=true);
    // Constants to be set in actual Medium
    constant Temperature T_min "Minimum temperature valid for medium model";
    constant Temperature T_max "Maximum temperature valid for medium model";
    constant Temperature T0=273.15 "reference Temperature";
    constant SpecificEnthalpy h0=0 "reference enthalpy at T0, reference_p";
    constant SpecificEntropy s0=0 "reference entropy at T0, reference_p";
    constant MolarMass MM_const=0.1 "Molar mass";
    constant Integer npol=2 "degree of polynomial used for fitting";
    constant Integer neta=size(tableViscosity,1) 
      "number of data points for viscosity";
    constant Real[:,:] tableDensity "Table for rho(T)";
    constant Real[:,:] tableHeatCapacity "Table for Cp(T)";
    constant Real[:,:] tableViscosity "Table for eta(T)";
    constant Real[:,:] tableVaporPressure "Table for pVap(T)";
    constant Real[:,:] tableConductivity "Table for lambda(T)";
    //    constant Real[:] TK=tableViscosity[:,1]+T0*ones(neta) "Temperature for Viscosity";
    constant Boolean TinK "true if T[K],Kelvin used for table temperatures";
    constant Boolean hasDensity = not (size(tableDensity,1)==0);
    constant Boolean hasHeatCapacity = not (size(tableHeatCapacity,1)==0);
    constant Boolean hasViscosity = not (size(tableViscosity,1)==0);
    constant Boolean hasVaporPressure = not (size(tableVaporPressure,1)==0);
    
    redeclare model extends BaseProperties(
      R=Modelica.Constants.R,
      p_bar=Cv.to_bar(p),
      T_degC(start = T_start-273.15)=Cv.to_degC(T),
      T(start = T_start, stateSelect=StateSelect.prefer),
      state(
        redeclare parameter Real poly_rho[npol+1](fixed=false),
        redeclare parameter Real poly_Cp[npol+1](fixed=false),
        redeclare parameter Real poly_eta[npol+1](fixed=false),
        redeclare parameter Real poly_pVap[npol+1](fixed=false),
        redeclare parameter Real poly_lam[npol+1](fixed=false),
        redeclare parameter Real invTK[neta](fixed=false))) 
      "Base properties of T dependent medium" 
      
      annotation(Documentation(info="
Note that the entropy neglects the pressure dependence, which is not strictly
true for an incompressible medium. Entropy is calculated as
  s = s0 + integral(Cp(T)/T,dt)
which is only exactly true for a fluid with constant density d=d0.
      "));
      SI.SpecificHeatCapacity cp "specific heat capacity";
      parameter SI.Temperature T_start = 298.15 "initial temperature";
      parameter Boolean includePdependence =  true 
        "include or neglect pressure dependence of spec. enthalpy" 
      annotation(Evaluate);
    initial equation 
      for i in 1:neta loop
        state.invTK[i] = 1/(if TinK then tableViscosity[i,1] else Cv.from_degC(tableViscosity[i,1]));
      end for;
      state.poly_rho =  if hasDensity then 
        Poly.fitting(tableDensity[:,1],tableDensity[:,2],npol) else 
           zeros(npol+1);
      state.poly_Cp = if hasHeatCapacity then 
        Poly.fitting(tableHeatCapacity[:,1],tableHeatCapacity[:,2],npol) else 
           zeros(npol+1);
      state.poly_eta = if hasViscosity then 
        Poly.fitting(state.invTK, Math.log(tableViscosity[:,2]),npol) else 
           zeros(npol+1);
      state.poly_pVap= if hasVaporPressure then 
        Poly.fitting(tableVaporPressure[:,1],tableVaporPressure[:,2],npol) else 
           zeros(npol+1);
      state.poly_lam = if size(tableConductivity,1)>0 then 
        Poly.fitting(tableConductivity[:,1],tableConductivity[:,2],npol) else 
           zeros(npol+1);
    equation 
      assert(hasDensity,"Medium " + mediumName +
                        " can not be used without assigning tableDensity.");
      assert(T >= T_min and T <= T_max, "Temperature T (= " + String(T) +
             " K) is not in the allowed range (" + String(T_min) +
             " K <= T <= " + String(T_max) + " K) required from medium model \""
             + mediumName + "\".");
      cp = Poly.evaluate(state.poly_Cp,if TinK then T else T_degC);
      h = h0 + Poly.integralValue(state.poly_Cp,if TinK then T else T_degC,
        if TinK then T0 else Cv.to_degC(T0)) + (if includePdependence then 
                (p - reference_p)/d*(1 + T/d*Poly.derivativeValue(state.poly_rho,if TinK then T else T_degC)) else 
                0.0);
    // investigate with Jonas!!!
      u = h - p/d;
      d = Poly.evaluate(state.poly_rho,if TinK then T else T_degC);
      state.T = T;
      state.p = p;
      MM = MM_const;
    end BaseProperties;
    
    redeclare function extends setState(state(
        redeclare parameter Real poly_rho[npol+1],
        redeclare parameter Real poly_Cp[npol+1],
        redeclare parameter Real poly_eta[npol+1],
        redeclare parameter Real poly_pVap[npol+1],
        redeclare parameter Real poly_lam[npol+1],
        redeclare parameter Real invTK[neta])) 
      "Returns state record including polynomial coefficients" 
      input SI.Pressure p "Pressure";
      input SI.Temperature T "Temperature";
    algorithm 
      state.p :=p;
      state.T :=T;
      for i in 1:neta loop
        state.invTK[i] :=1/(if TinK then tableViscosity[i, 1] else 
          Cv.from_degC(tableViscosity[i, 1]));
      end for;
      state.poly_rho :=if hasDensity then Poly.fitting(tableDensity[:, 1],
        tableDensity[:, 2], npol) else zeros(npol + 1);
      state.poly_Cp :=if hasHeatCapacity then Poly.fitting(
        tableHeatCapacity[:, 1], tableHeatCapacity[:, 2], npol) else zeros(npol
         + 1);
      state.poly_eta :=if hasViscosity then Poly.fitting(state.invTK,
        Math.log(tableViscosity[:, 2]), npol) else zeros(npol + 1);
      //        Poly.fitting({1/TK[i] for i in 1:neta},
      state.poly_pVap:=if hasVaporPressure then Poly.fitting(
        tableVaporPressure[:, 1], tableVaporPressure[:, 2], npol) else zeros(
        npol + 1);
      state.poly_lam :=if size(tableConductivity, 1) > 0 then Poly.fitting(
        tableConductivity[:, 1], tableConductivity[:, 2], npol) else zeros(npol
         + 1);
      // state.d :=Poly.evaluate(state.poly_rho, if TinK then T else 
      //  Cv.to_degC(T));
      // state.cp :=Poly.evaluate(state.poly_Cp, if TinK then T else 
      //  Cv.to_degC(T));
    end setState;
    
    redeclare function extends heatCapacity_cv 
      "Specific heat capacity at constant volume (or pressure) of medium" 
    algorithm 
      assert(hasHeatCapacity,"Specific Heat Capacity, Cv, is not defined for medium "
                                             + mediumName + ".");
      cv := Poly.evaluate(state.poly_Cp,if TinK then state.T else state.T - 273.15);
    end heatCapacity_cv;
    
    redeclare function extends heatCapacity_cp 
      "Specific heat capacity at constant volume (or pressure) of medium" 
    algorithm 
      assert(hasHeatCapacity,"Specific Heat Capacity, Cv, is not defined for medium "
                                             + mediumName + ".");
      cp := Poly.evaluate(state.poly_Cp,if TinK then state.T else state.T - 273.15);
    end heatCapacity_cp;
    
    redeclare function extends dynamicViscosity 
    algorithm 
      assert(size(tableViscosity,1)>0,"DynamicViscosity, eta, is not defined for medium "
                                             + mediumName + ".");
      eta := Math.exp(Poly.evaluate(state.poly_eta, 1/state.T));
    end dynamicViscosity;
    
    redeclare function extends thermalConductivity 
    algorithm 
      assert(size(tableConductivity,1)>0,"ThermalConductivity, lambda, is not defined for medium "
                                             + mediumName + ".");
      lambda := Poly.evaluate(state.poly_lam,if TinK then state.T else Cv.to_degC(state.T));
    end thermalConductivity;
    
    redeclare function extends specificEntropy 
    protected 
      Integer npol=size(state.poly_Cp,1)-1;
    algorithm 
      assert(hasHeatCapacity,"Specific Entropy, s(T), is not defined for medium "
                                             + mediumName + ".");
      s := s0 + (if TinK then 
        Poly.integralValue(state.poly_Cp[1:npol],state.T, T0) else 
        Poly.integralValue(state.poly_Cp[1:npol],Cv.to_degC(state.T),Cv.to_degC(T0)))
        + Modelica.Math.log(state.T/T0)*
        Poly.evaluate(state.poly_Cp,if TinK then 0 else Modelica.Constants.T_zero);
    end specificEntropy;
    
    function h_pT "Compute specific enthalpy from pressure and temperature" 
      extends Modelica.Icons.Function;
      input SI.Pressure p "Pressure";
      input SI.Temperature T "Temperature";
      input Boolean includePdependence = true 
        "include or neglect pressure dependence of spec. enthalpy"                                       annotation(Evaluate);
      output SI.SpecificEnthalpy h "Specific enthalpy at p, T";
      // annotation (InlineNoEvent=false);
    algorithm 
      
    end h_pT;
    
    package Polynomials_Temp 
      "Temporary Functions operating on polynomials (including polynomial fitting); only to be used in Modelica.Media.Incompressible.TableBased" 
      extends Modelica.Icons.Library;
      
      annotation (Documentation(info="<HTML>
<p>
This package contains functions to operate on polynomials,
in particular to determine the derivative and the integral
of a polynomial and to use a polynomial to fit a given set
of data points.
</p>
<p>
<p><b>Copyright (C) 2004, Modelica Association and DLR.</b></p>
<p><i>
This package is <b>free</b> software. It can be redistributed and/or modified
under the terms of the <b>Modelica license</b>, see the license conditions
and the accompanying <b>disclaimer</b> in the documentation of package
Modelica in file \"Modelica/package.mo\".
</i></p>
</HTML>
",     revisions="<html>
<ul>
<li><i>Oct. 22, 2004</i> by Martin Otter (DLR):<br>
       Renamed functions to not have abbrevations.<br>
       Based fitting on LAPACK<br>
       New function to return the polynomial of an indefinite integral<li>
<li><i>Sept. 3, 2004</i> by Jonas Eborn (Scynamics):<br>
       polyderval, polyintval added<li>
<li><i>March 1, 2004</i> by Martin Otter (DLR):<br>
       first version implemented
</li>
</ul>
</html>"),     uses(Modelica(version="2.1"), Modelica_Interpolation(version="0.94")));
      function evaluate "Evaluate polynomial at a given abszissa value" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        output Real y "Value of polynomial at u";
        annotation(derivative(noDerivative=p)=evaluate_der);
      algorithm 
        y := p[1];
        for j in 2:size(p, 1) loop
          y := p[j] + u*y;
        end for;
      end evaluate;
      
      function derivative "Derivative of polynomial" 
        extends Modelica.Icons.Function;
        input Real p1[:] 
          "Polynomial coefficients (p1[1] is coefficient of highest power)";
        output Real p2[size(p1, 1) - 1] "Derivative of polynomial p1";
      protected 
        Integer n=size(p1, 1);
      algorithm 
        for j in 1:n-1 loop
          p2[j] := p1[j]*(n - j);
        end for;
      end derivative;
      
      function derivativeValue 
        "Value of derivative of polynomial at abszissa value u" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        output Real y "Value of derivative of polynomial at u";
        annotation(derivative(noDerivative=p)=derivativeValue_der);
      protected 
        Integer n=size(p, 1);
      algorithm 
        y := p[1]*(n - 1);
        for j in 2:size(p, 1)-1 loop
          y := p[j]*(n - j) + u*y;
        end for;
      end derivativeValue;
      
      function secondDerivativeValue 
        "Value of 2nd derivative of polynomial at abszissa value u" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        output Real y "Value of 2nd derivative of polynomial at u";
      protected 
        Integer n=size(p, 1);
      algorithm 
        y := p[1]*(n - 1)*(n - 2);
        for j in 2:size(p, 1)-2 loop
          y := p[j]*(n - j)*(n - j - 1) + u*y;
        end for;
      end secondDerivativeValue;
      
      function integral "Indefinite integral of polynomial p(u)" 
        extends Modelica.Icons.Function;
        input Real p1[:] 
          "Polynomial coefficients (p1[1] is coefficient of highest power)";
        output Real p2[size(p1, 1) + 1] 
          "Polynomial coefficients of indefinite integral of polynomial p1 (polynomial p2 + C is the indefinite integral of p1, where C is an arbitrary constant)";
      protected 
        Integer n=size(p1, 1) + 1 "degree of output polynomial";
      algorithm 
        for j in 1:n-1 loop
          p2[j] := p1[j]/(n-j);
        end for;
      end integral;
      
      function integralValue "Integral of polynomial p(u) from u_low to u_high" 
        extends Modelica.Icons.Function;
        input Real p[:] "Polynomial coefficients";
        input Real u_high "High integrand value";
        input Real u_low=0 "Low integrand value, default 0";
        output Real integral=0.0 
          "Integral of polynomial p from u_low to u_high";
        annotation(derivative(noDerivative=p)=integralValue_der);
      protected 
        Integer n=size(p, 1) "degree of integrated polynomial";
        Real y_low=0 "value at lower integrand";
      algorithm 
        for j in 1:n loop
          integral := u_high*(p[j]/(n - j + 1) + integral);
          y_low := u_low*(p[j]/(n - j + 1) + y_low);
        end for;
        integral := integral - y_low;
      end integralValue;
      
      function fitting 
        "Computes the coefficients of a polynomial that fits a set of data points in a least-squares sense" 
        extends Modelica.Icons.Function;
        input Real u[:] "Abscissa data values";
        input Real y[size(u, 1)] "Ordinate data values";
        input Integer n(min=1) 
          "Order of desired polynomial that fits the data points (u,y)";
        output Real p[n + 1] 
          "Polynomial coefficients of polynomial that fits the date points";
        annotation (Documentation(info="<HTML>
<p>
Polynomials.fitting(u,y,n) computes the coefficients of a polynomial
p(u) of degree \"n\" that fits the data \"p(u[i]) - y[i]\"
in a least squares sense. The polynomial is
returned as a vector p[n+1] that has the following definition:
</p>
<pre>
  p(u) = p[1]*u^n + p[2]*u^(n-1) + ... + p[n]*u + p[n+1];
</pre>
</HTML>"));
      protected 
        Real V[size(u, 1), n + 1] "Vandermonde matrix";
      algorithm 
        // Construct Vandermonde matrix
        V[:, n + 1] := ones(size(u, 1));
        for j in n:-1:1 loop
          V[:, j] := {u[i] * V[i, j + 1] for i in 1:size(u,1)};
        end for;
        
        // Solve least squares problem
        p :=Modelica.Math.Matrices.leastSquares(V, y);
      end fitting;
      
      function evaluate_der "Evaluate polynomial at a given abszissa value" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        input Real du "Abszissa value";
        output Real dy "Value of polynomial at u";
      protected 
        Integer n=size(p, 1);
      algorithm 
        dy := p[1]*(n - 1);
        for j in 2:size(p, 1)-1 loop
          dy := p[j]*(n - j) + u*dy;
        end for;
        dy := dy*du;
      end evaluate_der;
      
      function integralValue_der 
        "time derivative of integral of polynomial p(u) from u_low to u_high, assuming only u_high as time-dependent (Leibnitz rule)" 
        extends Modelica.Icons.Function;
        input Real p[:] "Polynomial coefficients";
        input Real u_high "High integrand value";
        input Real u_low=0 "Low integrand value, default 0";
        input Real du_high "High integrand value";
        input Real du_low=0 "Low integrand value, default 0";
        output Real dintegral=0.0 
          "Integral of polynomial p from u_low to u_high";
      algorithm 
        dintegral := evaluate(p,u_high)*du_high;
      end integralValue_der;
      
      function derivativeValue_der 
        "time derivative of derivative of polynomial" 
        extends Modelica.Icons.Function;
        input Real p[:] 
          "Polynomial coefficients (p[1] is coefficient of highest power)";
        input Real u "Abszissa value";
        input Real du "delta of abszissa value";
        output Real dy 
          "time-derivative of derivative of polynomial w.r.t. input variable at u";
      protected 
        Integer n=size(p, 1);
      algorithm 
        dy := secondDerivativeValue(p,u)*du;
      end derivativeValue_der;
    end Polynomials_Temp;
    
  end TableBased_old;
end Incompressible;
