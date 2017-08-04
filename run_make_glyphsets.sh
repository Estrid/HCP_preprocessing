##Requires FREESURFER

subject_list='/home/estrid/scripts/test.txt'
subjects=$( cat ${subject_list} )
for subject in $subjects
do

echo $subject
date
/home/estrid/scripts/make_glyphsets.sh $subject /home/estrid/pamina_mount/HCP/HCP_S1200_subjects /home/estrid/pamina_mount/HCP/HCP_S1200_glyphsets

cd /home/estrid/pamina_mount/HCP/HCP_S1200_glyphsets/$subject/

mris_convert L.pial.asc lh.pial
mris_convert L.midthickness.asc lh.midthickness
mris_convert L.inflated.asc lh.inflated
mris_convert L.very_inflated.asc lh.very_inflated

mris_convert R.pial.asc rh.pial
mris_convert R.midthickness.asc rh.midthickness
mris_convert R.inflated.asc rh.inflated
mris_convert R.very_inflated.asc rh.very_inflated

done
