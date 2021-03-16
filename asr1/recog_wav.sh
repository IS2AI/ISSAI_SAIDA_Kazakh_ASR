#!/bin/bash

# Copyright 2019 Nagoya University (Takenori Yoshimura)
#           2019 RevComm Inc. (Takekatsu Hiramura)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

if [ ! -f path.sh ] || [ ! -f cmd.sh ]; then
    echo "Please change current directory to recipe directory e.g., egs/kaz_asr/asr1"
    exit 1
fi

. ./path.sh

# general configuration
backend=pytorch
stage=0       # start from 0 if you need to start from data preparation
stop_stage=100
ngpu=0         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
verbose=1      # verbose option

# feature configuration
do_delta=false

# rnnlm related
use_lang_model=true
lang_model= #if use_lang_model=true, path to rnnlm.model.best

# decoding parameter
cmvn= #path to cmvn.ark for example data/train/cmvn.ark
recog_model= #path to e2e model, for example in case of transformer: model.last10.avg.best 
decode_config=conf/decode_transformer.yaml
decode_dir=decode

api=v2

# download related


. utils/parse_options.sh || exit 1;

# make shellcheck happy
train_cmd=
decode_cmd=

. ./cmd.sh

wav=$1

set -e
set -u
set -o pipefail


# Check file existence
if [ ! -f "${cmvn}" ]; then
    echo "No such CMVN file: ${cmvn}"
    exit 1
fi
if [ ! -f "${lang_model}" ] && ${use_lang_model}; then
    echo "No such language model: ${lang_model}"
    exit 1
fi
if [ ! -f "${recog_model}" ]; then
    echo "No such E2E model: ${recog_model}"
    exit 1
fi
if [ ! -f "${decode_config}" ]; then
    echo "No such config file: ${decode_config}"
    exit 1
fi
if [ ! -f "${wav}" ]; then
    echo "No such WAV file: ${wav}"
    exit 1
fi

base=$(basename $wav .wav)
decode_dir=${decode_dir}/${base}

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    echo "stage 0: Data preparation"

    mkdir -p ${decode_dir}/data
    echo "$base $wav" > ${decode_dir}/data/wav.scp
    
    #sed -i.bak -e "s/$/ | sox -R -t wav - -t wav - rate 16000 dither | /" ${decode_dir}/data/wav.scp
    replacement=" /usr/bin/sox "
    pattern="[[:space:]]"
    sed -i.bak -e "s@$pattern@$replacement@" ${decode_dir}/data/wav.scp
    sed -i.bak -e "s/$/ -r 16000 -c 1 -b 16 -t wav - downsample | sox -R -t wav - -t wav - rate 16000 dither | /" ${decode_dir}/data/wav.scp

    echo "X $base" > ${decode_dir}/data/spk2utt
    echo "$base X" > ${decode_dir}/data/utt2spk
    echo "$base X" > ${decode_dir}/data/text
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo "stage 1: Feature Generation"

    steps/make_fbank_pitch.sh --cmd "$train_cmd" --nj 1 --write_utt2num_frames true \
        ${decode_dir}/data ${decode_dir}/log ${decode_dir}/fbank

    feat_recog_dir=${decode_dir}/dump; mkdir -p ${feat_recog_dir}
    dump.sh --cmd "$train_cmd" --nj 1 --do_delta ${do_delta} \
        ${decode_dir}/data/feats.scp ${cmvn} ${decode_dir}/log \
        ${feat_recog_dir}
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "stage 2: Json Data Preparation"

    dict=${decode_dir}/dict
    echo "<unk> 1" > ${dict}
    feat_recog_dir=${decode_dir}/dump
    data2json.sh --feat ${feat_recog_dir}/feats.scp \
        ${decode_dir}/data ${dict} > ${feat_recog_dir}/data.json
    rm -f ${dict}
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 3: Decoding"
    if ${use_lang_model}; then
        recog_opts="--rnnlm ${lang_model}"
    else
        recog_opts=""
    fi
    feat_recog_dir=${decode_dir}/dump

    ${decode_cmd} ${decode_dir}/log/decode.log \
        asr_recog.py \
        --config ${decode_config} \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --debugmode ${debugmode} \
        --verbose ${verbose} \
        --recog-json ${feat_recog_dir}/data.json \
        --result-label ${decode_dir}/result.json \
        --model ${recog_model} \
        --api ${api} \
        ${recog_opts}

    echo ""
    recog_text=$(grep rec_text ${decode_dir}/result.json | sed -e 's/.*: "\(.*\)".*/\1/' | sed -e 's/<eos>//')
    echo "Recognized text: ${recog_text}"
    echo ""
    echo "Finished"
fi