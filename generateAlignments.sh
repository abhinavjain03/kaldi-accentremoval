#!/bin/bash

. ./path.sh
. ./cmd.sh

dataLocation=/net/voxel10/misc/extra/data/abhinav/swbd/s5c
mfccdir=$dataLocation/mfcc
exp=$dataLocation
model=$dataLocation/trainedModels_onespkmanyseg

mfcc=0
decode=0
align=1

if [ $mfcc -eq 1 ]; then
	for x in train test val; do
		#utils/fix_data_dir.sh data/$x
		steps/make_mfcc.sh --nj 4 --cmd "$train_cmd" \
			data/assi_$x $exp/make_mfcc/assi_$x $mfccdir
		steps/compute_cmvn_stats.sh data/assi_$x $exp/make_mfcc/assi_$x $mfccdir
		utils/fix_data_dir.sh data/assi_$x
	done
fi


if [ $decode -eq 1 ]; then
	graph_dir=$model/tri4/graph_sw1_tg
	for x in train test val; do
		steps/decode_fmllr.sh --nj 4 --cmd "$decode_cmd" --skip-scoring true \
      	$graph_dir data/assi_$x $model/tri4/decode_assi_$x
    done
fi

if [ $align -eq 1 ]; then
	for x in train test val; do
		for i in {1..4} ; do
			lattice-1best ark:$model/tri4/decode_assi_$x/lat.${i} ark:- | \
				nbest-to-linear ark:- ark:- | \
				ali-to-phones --per-frame=true $model/tri4/final.mdl ark:- ark,t:$model/tri4/decode_assi_$x/$i.txt
		done
    done
fi