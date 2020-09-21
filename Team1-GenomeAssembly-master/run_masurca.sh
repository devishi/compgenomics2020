#!/bin/bash
get_input () {
        # Function for doing getopts

        # Setting default number of threads as 4
        threads=4

        while getopts "t:m:p:o:vh" option
        do
                case $option in
                        t) threads=$OPTARG;;
                        p) pathToInputFiles=$OPTARG;;
                        o) outputFolder=$OPTARG;;
                        m) masurcaPath=$OPTARG;;
			h) info_usage=1;;
                        v) verbose=1;;
                        *) echo "Incorrect arguments used. Use -h to know about the arguments available."
                esac
        done

        if ((info_usage)); then
                echo -e "The script contains a pipeline for running MaSuRCA.\nRun the script in the following format after giving the script executable permission:\n./run_masurca.sh\nArguments available\n\t-m <Path to MaSuRCA executable in it's bin>\n\t-p <Path to folder containing input fastq forward and backward reads annotated as <name>_1 and <name>_2 and are gzipped>\n\t-o <Path to output folder>\n\t-t <Number of threads>\n\t-v \tVerbose mode\n\t-h\tPrint usage information"
                exit
        fi
}


get_input "$@"

if ((verbose)); then
	echo "\nMaking output directory\n"
fi

mkdir ${outputFolder}/masurca_output

if ((verbose)); then
        echo "\nStarted genome assembly\n"
fi

for v in `ls ${pathToInputFiles}/* | grep _1.fq.gz | xargs -I gw basename -s _1.fq.gz gw`
do
        echo "MaSuRCA run for $v"
        mkdir ${outputFolder}/masurca_output/${v}_output
        gunzip ${pathToInputFiles}/${v}_1.fq.gz
        IFS=- read var1 var2 <<< `awk 'BEGIN { t=0.0;sq=0.0; n=0;} ;NR%4==2 {n++;L=length($0);t+=L;sq+=L*L;}END{m=t/n;printf("%d-%d\n",m+1,sq/n-m*m+5);}' ${pathToInputFiles}/${v}_1.fq`
        sed "s/CGT1001_trim/${v}/g" masurca_config.txt > ${outputFolder}/masurca_output/${v}_output/config.txt
	sed -i "s/250 100/$var1 $var2/g" ${outputFolder}/masurca_output/${v}_output/config.txt
        sed -i "s/NUM_THREADS = 16/NUM_THREADS = ${threads}/g" ${outputFolder}/masurca_output/${v}_output/config.txt
        gzip ${pathToInputFiles}/${v}_1.fq
        cd ${outputFolder}/masurca_output/${v}_output
        ${masurcaPath} ${outputFolder}/masurca_output/${v}_output/config.txt
        bash ${outputFolder}/masurca_output/${v}_output/assemble.sh
        cd ${outputFolder}
done
