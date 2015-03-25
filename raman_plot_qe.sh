#!/bin/bash
#
# raman_plot_qe.sh
# 
# Ver 0.1
#
# Description
# Plot Raman espectrum with points from Quantum Espresso calculation using lorentzian function in gnuplot.
# 
# Create by Ricky Nelson Burgos Gavelán
# Contributor: Thiago Andrade de Toledo
#
# raman_plot_qe.sh is distributed in the hope that it will be useful,
# but, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENTMIT License (see MIT LICENSE)
#
#########################################################################################################

if [ $# -eq 0 -o $# -gt 6 ]; then
  echo "
Usage: $0 [-p=#] [-e=plotfiletype]  <datafile> [nameplot] [-FWHM=#] -title=\"Title Raman\"
  
p: 1 Plot with only lorentzian Sum function (default value).
   2 Plot 1 and every lorentzian function under sum function.
   3 Plot 2 and every lorentzian function without sum function.
   4 Plot 3 and every center (with impulses) in lorentzian Sum function.
   5 Plot 4 and every center (with impulses) in lorentzian function under sum function.

plotfiletype: eps, ps, png (or any filetype supported by gnuplot).

Required <datafile>

######################## -p4 and -p5 No implemented yet ############################ 

FWHM Full width at half maximum, for lorentzian function in plot.

Example: raman_plot_qe.sh ATD_data.dat
Plot only sum lorentzian function and name plot file 'ATD_data.ps' and FWHM=5
"
  exit 
fi

plot_number=1
extension="ps"
FWHM=5
plot_title="Plot"


for i in "$@"
do
  case $i in
       -p=*)
       plot_number="${i#*=}"
       shift
       ;;
       -e=*)
       extension="${i#*=}"
       shift
       ;;
       -FWHM=*)
       FWHM="${i#*=}"
       shift
       ;;
       -title=*)
       plot_title="${i#*=}"
       shift
       ;;
       *)
       if [ -a $i ]; then
         if [ $(file --mime-type -b "$i") == "text/plain" ]; then
            filedat=$i
            fileplot=${i%.*}
         else
            fileplot=$i
         fi
       else
         fileplot=$i
       fi
       shift
       ;;
   esac
done

case $extension in
     tex)
     terminal="latex"
     shift
     ;;
     cgm)
     terminal="cgm color solid font \",12\" size 10in,6in"
     shift
     ;;
     dxf)
     terminal="dxf"
     shift
     ;;
     ps)
     terminal="eps enhanced color solid font \",12\" size 10in,6in"
     shift
     ;;
     png)
     terminal="png truecolor enhanced font arial 24 medium size 1024,768 background '#ffffff' "
     shift
     ;;
     jpg)
     terminal="jpeg font \"arial,12\""
     shift
     ;;
     svg)
     terminal="svg size 1024,768  font \",24\""
     shift
     ;;
esac

if [ ! -e "$filedat" ]; then
  echo "Error!!! file $filedat not exist..."
  exit
fi

folderOutPut="./"${filedat%.*}

if [ ! -d $folderOutPut ];
 then
 mkdir $folderOutPut
fi

plotNum=("
set output \"$fileplot-sum.$extension\"
plot slm(x)/max_raman lw 2 title \"Raman Simulation\"" "

set output \"$fileplot-modes.$extension\"
set table \"$fileplot-modes.dat\"
plot for[i=2:words(freq)] lm(x,word(freq, i),word(ampl, i),w)/max_raman lw 1.5 title \"\"
unset table
plot for[i=2:words(freq)] lm(x,word(freq, i),word(ampl, i),w)/max_raman lw 1.5 title \"\"" "

set output \"$fileplot-sum-modes.$extension\"
plot slm(x)/max_raman lw 2 title \"Raman Simulation\", \
     for[i=2:words(freq)] lm(x,word(freq, i),word(ampl, i),w)/max_raman lw 1.5 title \"\"")

plot_total=${plotNum[0]}
     
if [ $plot_number -gt 1 ]; then
  for (( i=1; i < $plot_number; i++ ))
  do
    plot_total=$plot_total"${plotNum[i]}"
  done
fi

######################################################################################################################

cp $filedat $folderOutPut/.

echo "Do You want create plot files? (Y[es] or N[o])"
read YesNot

case YesNot in
     "Y")
     Ans=true
     shift
     ;;
     "y")
     Ans=true
     shift
     ;;
     "Yes")
     Ans=true
     shift
     ;;
     "yes")
     Ans=true
     shift
     ;;
     *) 
     Ans=false
     echo "No plot..."
     shift
     ;;
esac

######################################################################################################################
if [ "$Ans" = false ]; then
gnuplot <<EOF

#Data file
datafile="$filedat"
stats datafile using 2:5 name "dat" nooutput

#Array dimesion
count=int(dat_records)
#Array data
freq = system("awk '{if(\$5 != 0.0) printf(\"%f \",\$2)}' " .datafile)
ampl = system("awk '{if(\$5 != 0.0) printf(\"%f \",\$5)}' " .datafile)

#######################################################################################################################
#Experimenal Correction - Absolut Intesity Convertion to Relative Intesity
#Laser line
lline=2491.9
I(f,a)=1.0e-12*((lline-f)**4)*a/f
#######################################################################################################################

#Maximum value to normalize
maxValueAmp = 0.0
do for[i=2:words(ampl)] { if(maxValueAmp < I(word(freq,i),word(ampl,i))){maxValueAmp = I(word(freq,i),word(ampl,i)) }}

#FWHM
w=$FWHM

#Lorentzian function normalized #######
l(x,xc,ac,wc)=wc*(I(xc,ac)/(wc**2+(x-xc)**2))

#remain normalized amplitud
lm(x,xc,ac,wc) = wc*l(x,xc,ac,wc)/maxValueAmp

#Lorentzian function (sum)
slm(x) = sum[i=2:words(freq)] lm(x,word(freq, i),word(ampl, i),w)

#more point
set samples 5000

#Define scale
margin=10
start=real(dat_min_x)-margin*w
end=real(dat_max_x)+margin*w

set xrange [start:end]
   
set table "$folderOutPut/$fileplot-sum.dat"
plot slm(x)

stats "$folderOutPut/$fileplot-sum.dat" using 1:2 name "raman" nooutput
max_raman = raman_max_y
unset table

set table "$folderOutPut/$fileplot-sum.dat"
plot slm(x)/max_raman title "Raman Simulation"
unset table

set table "$folderOutPut/$fileplot-modes.dat"
plot for[i=2:words(freq)] lm(x,word(freq, i),word(ampl, i),w)/max_raman lw 1.5 title sprintf("Mode %d",i-1)
unset table


EOF
fi

######################################################################################################################
cat > $folderOutPut/$fileplot.gp <<EOF
set terminal $terminal

set title "$plot_title Raman Simulation" font "Arial-Bold,14"

#Data file
datafile="$filedat"
stats datafile using 2:5 name "dat" nooutput

#Array dimesion
count=int(dat_records)
#Array data
freq = system("awk '{if(\$5 != 0.0) printf(\"%f \",\$2)}' " .datafile)
ampl = system("awk '{if(\$5 != 0.0) printf(\"%f \",\$5)}' " .datafile)

#######################################################################################################################
#Experimenal Correction - Absolut Intesity Convertion to Relative Intesity
#Laser line
lline=2491.9
I(f,a)=1.0e-12*((lline-f)**4)*a/f
#######################################################################################################################

#Maximum value to normalize
maxValueAmp = 0.0
do for[i=2:words(ampl)] { if(maxValueAmp < I(word(freq,i),word(ampl,i))){maxValueAmp = I(word(freq,i),word(ampl,i)) }}

#FWHM
w=$FWHM

#Lorentzian function normalized #######
l(x,xc,ac,wc)=wc*(I(xc,ac)/(wc**2+(x-xc)**2))

#remain normalized amplitud
lm(x,xc,ac,wc) = wc*l(x,xc,ac,wc)/maxValueAmp

#Lorentzian function (sum)
slm(x) = sum[i=2:words(freq)] lm(x,word(freq, i),word(ampl, i),w)

#more point
set samples 5000

#Define scale
margin=10
start=real(dat_min_x)-margin*w
end=real(dat_max_x)+margin*w

set xlabel "{Raman Shift} (cm^{-1})"
set ylabel "Raman Intensity (arb. units)"

set xrange [start:end]

set xtics nomirror out
#set ytics nomirror out scale 0

#without tics y
unset ytics 
#set format y "" 
     
set table "$fileplot-sum.dat"
plot slm(x)
stats "$fileplot-sum.dat" using 1:2 name "raman" nooutput
max_raman = raman_max_y
unset table
set table "$fileplot-sum.dat"
plot slm(x)/max_raman title "Raman Simulation"
unset table

set yrange [-.01:1.01]

$plot_total

reset

EOF

############################################################################################################################

cat > $folderOutPut/$fileplot-sum.gp <<EOF
set terminal $terminal

set title "$plot_title Raman Simulation" font "Arial-Bold,14"

datafile="$fileplot-sum.dat"
stats datafile using 1:2 name "dat" nooutput

#more point
set samples 5000

#Define scale
start=real(dat_min_x)
end=real(dat_max_x)

set xlabel "{Raman Shift} (cm^{-1})"
set ylabel "Raman Intensity (arb. units)"

set xrange [start:end]

set xtics nomirror out
#set ytics nomirror out scale 0

#without tics y
unset ytics 
#set format y "" 

set yrange [-.01:1.01]

set output "$fileplot-sum.$extension"
plot "$fileplot-sum.dat" w l lw 2 title "Raman Simulation"

reset

EOF
#######################################################################################################################

if [ $plot_number -gt 1 ]; then
cat > $folderOutPut/$fileplot-modes.gp <<EOF
set terminal $terminal

set title "$plot_title Raman Simulation" font "Arial-Bold,14"

datafile="$fileplot-modes.dat"
stats datafile using 1:2 name "dat" nooutput

#more point
set samples 5000

#Define scale
start=real(dat_min_x)
end=real(dat_max_x)

set xlabel "{Raman Shift} (cm^{-1})"
set ylabel "Raman Intensity (arb. units)"

set xrange [start:end]

set xtics nomirror out
#set ytics nomirror out scale 0

#without tics y
unset ytics 
#set format y "" 

set yrange [-.01:1.01]

set output "$fileplot-modes.$extension"
plot "$fileplot-modes.dat" w l lw 2 title "Raman Simulation"

reset

EOF

if [ $plot_number -gt 2 ]; then
cat > $folderOutPut/$fileplot-sum-modes.gp <<EOF
set terminal $terminal

set title "$plot_title Raman Simulation" font "Arial-Bold,14"

datafile="$fileplot-modes.dat"
stats datafile using 1:2 name "dat" nooutput

#more point
set samples 5000

#Define scale
start=real(dat_min_x)
end=real(dat_max_x)

set xlabel "{Raman Shift} (cm^{-1})"
set ylabel "Raman Intensity (arb. units)"

set xrange [start:end]

set xtics nomirror out
#set ytics nomirror out scale 0

#without tics y
unset ytics 
#set format y "" 

set yrange [-.01:1.01]

set output "$fileplot-sum-modes.$extension"
plot "$fileplot-sum.dat" w l lw 2 title "Raman Simulation", plot "$fileplot-modes.dat" w l lw 2 title "Raman Simulation modes"

reset

EOF
fi
fi

#######################################################################################################################

if [ "$Ans" = true ]; then
   cd $folderOutPut
   gnuplot $fileplot.gp
fi
