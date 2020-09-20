# ISSAI_SAIDA_Kazakh_ASR
This repository provides the recipe for the paper [A Crowdsourced Open-Source Kazakh Speech Corpus](thelink). 

## Setup and Requirements 

Our code builds upon [ESPnet](https://github.com/espnet/espnet), and requires prior installation of the framework. Please follow the [installation guide](https://espnet.github.io/espnet/installation.html) and put the ksc folder inside `espnet/egs/` directory.

After succesfull installation of ESPnet & Kaldi, go to `ksc/asr1` and create links to the dependencies:
```
ln -s ../../../tools/kaldi/egs/wsj/s5/steps steps
ln -s ../../../tools/kaldi/egs/wsj/s5/utils utils
```
The directory for running the experiments (`ksc/<exp-name`) can be created by running the following script:

```
./setup_experiment.sh <exp-name>
```

## Downloading the dataset
 
Download ISSAI_KSC_335RS dataset and untar in the directory of your choice. Specify the path to the dataset inside `ksc/<exp-name>/conf/data_path.conf` file:
```
dataset_dir=/path-to/ISSAI_KSC_335RS
```

## Training

To train the models, run the script `./run.sh` inside` ksc/<exp-name>/` folder.

## Inference
To decode a single audio, specify paths to the following files inside `recog_wav.sh` script:
```
lang_model= path to rnnlm.model.best
cmvn= path to cmvn.ark for example data/train/cmvn.ark
recog_model= path to e2e model, in case of transformer: model.last10.avg.best 
```
Then, run the following script:
```
./recog_wav.sh <path-to-audio-file>
```
