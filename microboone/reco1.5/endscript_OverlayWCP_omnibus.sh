#!/bin/bash
source /cvmfs/uboone.opensciencegrid.org/products/setup_uboone.sh
#setup sam_web_client

workdir=`pwd`
touch wirecell.log

echo "################# Init of job" | tee -a wirecell.log

echo "larsoft and uboonecode version" | tee -a wirecell.log
echo $LARSOFT_VERSION | tee -a wirecell.log
echo $UBOONECODE_VERSION | tee -a wirecell.log
date | tee -a wirecell.log


input_celltree=""
input_artROOT=""
XROOTD_URI=""

input_celltree=`ls celltreeOVERLAY*.root | xargs | awk '{print $1}'`
if [ ! -e "$input_celltree" ]; then
	echo "Celltree root not found!" | tee -a wirecell.log
	exit 201 
fi
echo "celltree input: $input_celltree" | tee -a wirecell.log
#if [ -e "$input_celltree" ]; then
#	#### the last matched file
#	input_artROOT0=`samweb list-files "defname: $RECO1_DATASET and isparentof:(file_name $input_celltree)" | xargs | awk '{print $NF}'`
#	echo "Matched reco1: $input_artROOT0" | tee -a wirecell.log	
#fi

# if there's naming issue (max length) this won't work.
# A general method should be tried
#input_artROOT0=`ls *_postwcct*.root | xargs | awk '{print $1}'`
#input_artROOT=${input_artROOT0%_detsim*}".root" #change parent file name. Be aware of how many fcls/stages run
#mv $input_artROOT0 $input_artROOT

# This is a better method
CPID=`cat cpid.txt`
input_artROOT=($(ifdh translateConstraints "consumer_process_id=$CPID and consumed_status consumed"))
stat=$?
if [ $stat -ne 0 ]; then
	if [ -f condor_lar_input.list ]; then
        	input_artROOT=`cat condor_lar_input.list | xargs basename`
	else
		echo "Failed to determine inputfile name!" | tee -a wirecell.log
     		exit 202
	fi
fi
echo "Input artROOT: $input_artROOT found!" | tee -a wirecell.log

input_artROOT0=`ls -t *.root | xargs | awk '{print $2}'` # the 2nd last one is the artROOT (since the last one is celltree.root)
ls -t *.root | tee -a wirecell.log
echo $input_artROOT0 | tee -a wirecell.log
mv $input_artROOT0 $input_artROOT

if [ ! -e "$input_artROOT" ]; then
	echo "Reco1 artROOT not found!" | tee -a wirecell.log
	exit 203
fi

#eventcount=5
### event_count: 5, 
eventcount=`grep event_count celltreeOVERLAY*.json | awk '{print substr($2, 1, length($2)-1)}'`

echo "Make WCP work directory" | tee -a wirecell.log
echo `pwd`
mkdir WCPwork
cp $input_celltree WCPwork/

#echo "Checking tarball extraction" | tee -a wirecell.log
tar -xf $INPUT_TAR_FILE -C WCPwork

echo "Doing WCP setup" | tee -a wirecell.log
cd WCPwork 
source ./setup.sh
#setup wcp $WCP_VERSION -q e17:prof
echo "Create symlink to stash dCache WCP external data files" | tee -a ../wirecell.log
ln -s /cvmfs/uboone.osgstorage.org/stash/wcp_ups/wcp/releases/tag/v00_10_00/input_data_files input_data_files
ln -s /cvmfs/uboone.osgstorage.org/stash/wcp_ups/wcp/releases/tag/v00_10_00/uboone_photon_library.root uboone_photon_library.root
ls | tee -a ../wirecell.log 

#echo "Job process num"
#echo $PROCESS
date | tee -a ../wirecell.log
#for ((n=0; n<20; n++))
for ((n=0; n<$(($eventcount)); n++))
do
	echo "$n event processing starts." | tee -a ../wirecell.log
	wire-cell-imaging-lmem-celltree ./input_data_files/ChannelWireGeometry_v2.txt $input_celltree $n -d1 -s2 2>&1 | tee -a ../wirecell.log
	echo "$n event imaging finished." | tee -a ../wirecell.log
	echo "$n event matching starts."
	for imagingfile in result*.root
	do
		echo "$imagingfile" | tee -a ../wirecell.log
		input=$imagingfile
		input1=${input%.root}
		input2=${input1#*result_}
		echo $input2 | tee -a ../wirecell.log
		mv $imagingfile imaging_$input2.root
		#prod-nusel-eval ./input_data_files/ChannelWireGeometry_v2.txt imaging_$input2.root -d1 -p1 2>&1 | tee -a ../wirecell.log
		prod-wire-cell-matching-nusel ./input_data_files/ChannelWireGeometry_v2.txt imaging_$input2.root -d1 -z1 2>&1 | tee -a ../wirecell.log
		### Exception: "No points! Quit!" -- this is a "warning" instead of "error"!
		warning=`tail -n 1 ../wirecell.log`
		echo "$warning"
		if [ "$warning" = "No points! Quit! " ]; then
        		echo "WARNING!" | tee -a ../wirecell.log
			touch nuseldummy_${input2}.root
			touch portdummy_${input2}.root
		fi
	done
	echo "$n event matching finished."
done
date | tee -a ../wirecell.log

echo "Check the number of root files" | tee -a ../wirecell.log
nevts1=`ls nusel*.root | wc -l`
nevts2=`ls port*.root | wc -l`
if [ $nevts1 = $nevts2 -a $nevts1 = $eventcount ]; then
	echo "Good!" | tee -a ../wirecell.log
else
	echo "Bad: nusel $nevts1, port $nevts2, input $eventcount" | tee -a ../wirecell.log
 	##touch merge.root ### empty merge.root --> WCP failure	
	exit 204
fi


inputfilebase=`basename $input_artROOT`
bookkeep=${inputfilebase%.*}
echo "Merge output" | tee -a ../wirecell.log
ls *.root
hadd merge.root ./port_*.root
hadd nuselOVERLAY_WCP.root ./nuselEval_*.root
#mv imaging*.root $workdir
mv nuselOVERLAY_WCP.root $workdir
mv merge.root $workdir

cd $workdir
#cp merge.root ${bookkeep}_WCPport.root
echo "Done! Done! Done!" | tee -a wirecell.log
date | tee -a wirecell.log


echo "+++++++++++++++++++++++++++++"
echo "art port"
# change nuselEval json file
#sed -i "s/_detsim_mix.root/.root/g" nusel*.root.json

#make a new wrapper.fcl (Stage?.fcl)
# find the last stage
laststagefcl=`ls -l Stage*.fcl | xargs | awk '{print $NF}'`
sed -e "s/run_celltreeub\(.*\).fcl/run_slimmed_port_overlay.fcl/g" -e "s/FCLName:.*\"/FCLName: \"run_slimmed_port_overlay.fcl\"/g" $laststagefcl > port.fcl #multiple fhicls/stages, use the celltree one (last one) to generate the port stage fcl including all necessary metadata
# copy fhicl
cp $CONDOR_DIR_INPUT/run_slimmed_port_overlay.fcl .
lar -c port.fcl -n 200000 -s $input_artROOT | tee -a wirecell.log
rm $input_artROOT # duplicated reco1 artROOT
rm $input_celltree 
rm merge.root
rm reco_stage_*_hist.root
rm detsim_hist.root
rm DataOverlayMixer_hist.root

exit 0 
