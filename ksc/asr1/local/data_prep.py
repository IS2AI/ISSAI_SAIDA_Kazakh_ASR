#!/usr/bin/env python

import sys, argparse, re, os, pdb
import pandas as pd
from pathlib import Path
import wave
import contextlib

seed=4

def get_args():
    parser = argparse.ArgumentParser(description="", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--dataset_dir", help="Input data directory", required=True)
    parser.add_argument("--train_file", help="relative path train list", default='')
    parser.add_argument("--dev_file", default='')
    parser.add_argument("--test_file", default='')
    print(' '.join(sys.argv))
    args = parser.parse_args()
    return args


def get_duration(file_path):
    duration = None
    if os.path.exists(file_path) and Path(file_path).stat().st_size > 0:
        with contextlib.closing(wave.open(file_path,'r')) as f:
            frames = f.getnframes()
            if frames>0:
                rate = f.getframerate()
                duration = frames / float(rate)
    return duration if duration else 0
            
def read_meta(path):
    meta = pd.read_csv(path, sep=" ") 
    return list(meta['uttID'])
    
def get_text(dataset_dir, file):
    txt_file = os.path.join(dataset_dir, 'Transcriptions', file) + '.txt'
    with open(txt_file, 'r') as f:
        return f.read().strip()

def prepare_data(dataset_dir, path_root, files):
    files.sort()
    total_duration = 0
    wav_format = '-r 16000 -c 1 -b 16 -t wav - downsample |'
    
    with open(path_root + '/text', 'w', encoding="utf-8") as f1, \
    open(path_root + '/utt2spk', 'w', encoding="utf-8") as f2, \
    open(path_root + '/wav.scp', 'w', encoding="utf-8") as f3:
        for instance in files: 
            filename = instance.strip()
            file_path = os.path.join(dataset_dir, 'Audios', filename) + '.wav'
           
            total_duration += get_duration(file_path) 
            
            transcription = get_text(dataset_dir, filename)

            f1.write(filename + ' ' + transcription + '\n')
            f2.write(filename + ' ' + filename + '\n')
            f3.write(filename + ' sox ' + file_path  + ' ' + wav_format +  '\n') 
            
    return total_duration / 3600

def main():
    args = get_args()
    
    dataset_dir = args.dataset_dir
    train_file = os.path.join(dataset_dir, args.train_file)
    dev_file = os.path.join(dataset_dir, args.dev_file)
    test_file = os.path.join(dataset_dir, args.test_file)
    
    train = []
    dev = []
    test = []
    train_dir_name = 'train'
    dev_dir_name = 'dev'
    test_dir_name = 'test'
    
    save_data_root = 'data/'
    train_root = save_data_root + train_dir_name
    dev_root = save_data_root + dev_dir_name
    test_root = save_data_root + test_dir_name
    
    if os.path.isfile(train_file): 
        train = read_meta(train_file)
        print('duration of train data:', prepare_data(dataset_dir, train_root, train))
        
    if os.path.isfile(dev_file): 
        dev = read_meta(dev_file)
        print('duration of dev data:', prepare_data(dataset_dir, dev_root, dev))
        
    if os.path.isfile(test_file): 
        test = read_meta(test_file)
        print('duration of test data:', prepare_data(dataset_dir, test_root, test))

if __name__ == "__main__":
    main()
