. ./path.sh
. ./cmd.sh

#DIRECTORIES
exp=exp
swbd_exp=swbd_exp

mfccdir=$exp/mfcc_hires_text

#VARIABLES
nj=6
# train_sets="test_cslu_hi train_swbd_259890"
train_sets="train_swbd_259890"

mfcc_text=0
merge_across_jobs=0
generate_phone_sequence=1

if [ $mfcc_text -eq 1 ]; then
	for x in $train_sets; do
		#utils/fix_data_dir.sh data/$x
		steps/make_mfcc_text.sh --nj $nj --cmd "$train_cmd" \
		    --mfcc-config conf/mfcc_hires.conf \
			data/${x}_hires $exp/make_mfcc/${x}_hires $mfccdir
	done
fi


if [ $merge_across_jobs -eq 1 ]; then
	for x in $train_sets; do
		for n in $(seq $nj);do 
			cat $mfccdir/raw_mfcc_${x}_hires.$n.txt; 
		done > $mfccdir/raw_mfcc_${x}_hires_merged.txt
		echo "Merging Done!"
	done
fi

if [ $generate_phone_sequence -eq 1 ]; then

	mfcc=0
	decode_main=1
	align=0

	mfccdir=$exp/mfcc_hires
	decode_model=${exp}/nnet3/tdnn_d_sp

	if [ $mfcc -eq 1 ]; then
		for x in $train_sets; do
			#utils/fix_data_dir.sh data/$x
			steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
				--mfcc-config conf/mfcc_hires.conf \
				data/${x}_hires $exp/make_mfcc/${x}_hires $mfccdir
			steps/compute_cmvn_stats.sh data/${x}_hires $exp/make_mfcc/${x}_hires $mfccdir
			utils/fix_data_dir.sh data/${x}_hires
		done
	fi

	if [ $decode_main -eq 1 ]; then

		ivectors=0
		decode=1

		if [ $ivectors -eq 1 ]; then
			for x in $train_sets; do
				steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
					data/${x}_hires \
					${swbd_exp}/trainedModels_onespkmanyseg/nnet_online/extractor \
					${exp}/nnet3/ivectors_${x}_hires || exit 1;
			done
		fi

		if [ $decode -eq 1 ]; then

			graph_dir=${swbd_exp}/trainedModels_onespkmanyseg/tri4/graph_sw1_tg
			for x in $train_sets; do
				steps/nnet3/decode.sh --nj $nj --cmd "$decode_cmd" \
					--online-ivector-dir ${exp}/nnet3/ivectors_${x}_hires \
					$graph_dir data/${x}_hires ${decode_model}/decode_${x}_hires || exit 1;
			done

		fi
	fi

	if [ $align -eq 1 ]; then

		for x in $train_sets; do
			for i in $(seq $nj) ; do
				gunzip -c ${decode_model}/decode_${x}_hires/lat.$i.gz > ${decode_model}/decode_${x}_hires/lat.$i
			done
		done

		for x in $train_sets; do
			for i in $(seq $nj) ; do
				lattice-1best ark:${decode_model}/decode_${x}_hires/lat.${i} ark:- | \
					nbest-to-linear ark:- ark:- | \
					ali-to-phones --per-frame=true ${decode_model}/decode_${x}_hires/final.mdl \
					ark:- ark,t:${decode_model}/decode_${x}_hires/$i.txt
			done
    	done

	    for x in $train_sets; do
			for n in $(seq $nj);do 
				cat ${decode_model}/decode_${x}_hires/$n.txt; 
			done > ${decode_model}/decode_${x}_hires/phone_alignments.txt
			echo "Merging Done!"
		done
	fi
fi


