##Requires FREESURFER
#!/bin/sh
# script for processing HCP Q3 fMRI FIX-denoised data for use in brainGL
# use as follows: make_glyphsets_HCP_Q3.sh <HCP directory, e.g. 100307> <data directory> <output directory>
# creates a new directory with:
# copy of anatomical background nifti
# surfaces in freesurfer format
# .set files for these surfaces: l, r
# connectivity matrices for l, r
# .glyphset files for l, r

date  ## echo the date at start

# this needs to point at the human connectome workbench commandline program
workbench=/home/estrid/Software/workbench/bin_linux64/wb_command

#subject identifier
subName=${1}

# this needs to point at the directory where the HCP data is
datadir=${2}

# the directory where the sets get created
glyphsets=${3}
mkdir ${glyphsets}/${subName}

# copy of anatomical background
cp ${datadir}/${subName}/T1w/T1w_acpc_dc_restore_brain.nii.gz ${glyphsets}/${subName}

# convert surfaces to freesurfer (requires AFNI for the gifti_tool)
# create .set files for these surfaces
echo converting surfaces and writing set file...
for HEMI in R L; do
	rm ${glyphsets}/${subName}/LR.set
	for SURF in pial inflated very_inflated midthickness; do
		gifti_tool -infiles ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.${HEMI}.${SURF}_MSMAll.32k_fs_LR.surf.gii -write_asc ${glyphsets}/${subName}/${HEMI}.${SURF}.asc
		echo ${HEMI}.${SURF}.asc >> ${glyphsets}/${subName}/LR.set
	done
done

# connectivity data
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do
	
	# reduce cifti to cortex only
	cmd="$workbench -cifti-restrict-dense-map \
	${datadir}/${subName}/MNINonLinear/Results/rfMRI_${REST}_${PHASEDIR}/rfMRI_${REST}_${PHASEDIR}_Atlas_MSMAll_hp2000_clean.dtseries.nii \
	COLUMN \
	${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}.dtseries.nii \
	-left-roi ${datadir}/L.atlasroi.32k_fs_LR.shape.gii \
	-right-roi ${datadir}/R.atlasroi.32k_fs_LR.shape.gii"
	echo reducing cifti to cortex only...
	$cmd

    # smoothing 
    #wb_command -cifti-smoothing <cifti> <surface-kernel> <volume-kernel> <direction> <cifti-out> [-left-surface] <surface> [-right-surface] <surface>
    cmd="$workbench -cifti-smoothing \
    ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}.dtseries.nii \
    2 2 COLUMN \
    ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_smoothed.dtseries.nii \
    -left-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.L.very_inflated_MSMAll.32k_fs_LR.surf.gii \
    -right-surface ${datadir}/${subName}/MNINonLinear/fsaverage_LR32k/${subName}.R.very_inflated_MSMAll.32k_fs_LR.surf.gii"
    echo smoothing...
    $cmd

    # compute correlation matrix
    cmd="$workbench -cifti-correlation \
    ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_smoothed.dtseries.nii \
    ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_corr.nii -fisher-z"
    echo computing correlation matrix...
    $cmd

	done
done

# averaging sessions separately
for REST in REST1 REST2; do
    cmd="$workbench -cifti-average \
    ${glyphsets}/${subName}/rfMRI_${REST}_corr.nii \
    -cifti ${glyphsets}/${subName}/rfMRI_${REST}_RL_corr.nii \
    -cifti ${glyphsets}/${subName}/rfMRI_${REST}_LR_corr.nii"
    echo averaging RS sessions separately...
    $cmd

    # back to r
    $workbench -cifti-math 'tanh(z)' \
    ${glyphsets}/${subName}/rfMRI_${REST}_corr_avg.nii \
    -var z ${glyphsets}/${subName}/rfMRI_${REST}_corr.nii
    echo transforming z-to-r...

    # converion to external binary gifti: header file + the binary matrix we want for braingl
    cmd="$workbench -cifti-convert -to-gifti-ext \
    ${glyphsets}/${subName}/rfMRI_${REST}_corr_avg.nii \
    ${glyphsets}/${subName}/rfMRI_${REST}_corr_avg.gii"
    echo converting to external binary gifti...
    $cmd
done

# averaging sessions together
cmd="$workbench -cifti-average \
${glyphsets}/${subName}/rfMRI_REST_corr.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST1_RL_corr.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST1_LR_corr.nii
-cifti ${glyphsets}/${subName}/rfMRI_REST2_RL_corr.nii \
-cifti ${glyphsets}/${subName}/rfMRI_REST2_LR_corr.nii"
echo averaging RS sessions together...
$cmd

# back to r
$workbench -cifti-math 'tanh(z)' \
${glyphsets}/${subName}/rfMRI_REST_corr_avg.nii \
-var z ${glyphsets}/${subName}/rfMRI_REST_corr.nii
echo transforming z-to-r...

# converion to external binary gifti: header file + the binary matrix we want for braingl
cmd="$workbench -cifti-convert -to-gifti-ext \
${glyphsets}/${subName}/rfMRI_REST_corr_avg.nii \
${glyphsets}/${subName}/rfMRI_REST_corr_avg.gii"
echo converting to external binary gifti...
$cmd

# .glyphset files
echo writing glyphset file...
rm ${glyphsets}/${subName}/LR.glyphset
echo T1w_acpc_dc_restore_brain.nii.gz >> ${glyphsets}/${subName}/LR.glyphset
echo L.set >> ${glyphsets}/${subName}/LR.glyphset
echo rfMRI_REST_corr_avg.gii.data -1.0 1.0 >> ${glyphsets}/${subName}/LR.glyphset

# remove unnecessary files
echo removing unnecessary large files...
for REST in REST1 REST2; do
	for PHASEDIR in RL LR; do

    rm ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}_corr.nii
    rm ${glyphsets}/${subName}/rfMRI_${REST}_${PHASEDIR}.dtseries.nii

    rm ${glyphsets}/${subName}/rfMRI_REST_corr.nii
    rm ${glyphsets}/${subName}/rfMRI_${REST}_corr.nii
    rm ${glyphsets}/${subName}/rfMRI_REST_corr_avg.nii
    rm ${glyphsets}/${subName}/rfMRI_${REST}_corr_avg.nii
    rm ${glyphsets}/${subName}/rfMRI_REST_corr_avg.gii

	done
done

echo done.
date  ## echo the date at end
