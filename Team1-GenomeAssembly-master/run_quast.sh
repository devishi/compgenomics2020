#!/bin/bash
get_input () {
        # Function for doing getopts

        # Setting default number of threads as 4
        threads=4

        while getopts "t:q:p:u:o:m:vh" option
        do
                case $option in
                        t) threads=$OPTARG;;
			q) quastPath=$OPTARG;;
			p) pathToInputFiles=$OPTARG;;
                        u) pathToUnicyclerContig=$OPTARG;;
                        o) outputFolder=$OPTARG;;
                        m) pathToMaSuRCAContig=$OPTARG;;
			h) info_usage=1;;
                        v) verbose=1;;
                        *) echo "Incorrect arguments used. Use -h to know about the arguments available."
                esac
        done
	
        if ((info_usage)); then
                echo -e "The script contains a pipeline for running quast evaluation.\nRun the script in the following format after giving the script executable permission:\n./run_quast.sh\nArguments available\n\t-q <Path to quast.py file>\n\t-p <Path to input files>\n\t-u <Path to the Unicycler contig file>\n\t-m <Path to the MaSuRCA contig file>\n\t-o <Path to output folder>\n\t-t <Number of threads>\n\t-v \tVerbose mode\n\t-h\tPrint usage information"
                exit
        fi
}

get_input "$@"

if ((verbose)); then
	echo "\nMaking output directory\n"
fi

mkdir ${outputFolder}/quast_output
mkdir ${outputFolder}/assembled_output

if ((verbose)); then
        echo "\nStarted process of identification of Assembler to use\n"
fi

ls ${pathToInputFiles} | grep _1.fq.gz | xargs -I gw basename -s _1.fq.gz gw | xargs -I gwa python3 ${quastPath} ${pathToUnicyclerContig}/gwa_output/assembly.fasta ${pathToMaSuRCAContig}/gwa_output/CA/9-terminator/genome.ctg.fasta -o ${outputFolder}/quast_output/gwa -t ${threads} -l Unicycler,MaSuRCa 

for v in `ls ${pathToInputFiles} | grep _1.fq.gz | xargs -I gw basename -s _1.fq.gz gw`
do
	IFS='    ' read -a f<<< `grep 'Total length (>= 0 bp) ' ${outputFolder}/quast_output/${v}/report.txt`
	if (($(( f[5]-f[6] )) > $(( f[5]/10 )))); then
		cp ${pathToUnicyclerContig}/${v}_output/assembly.fasta ${outputFolder}/assembled_output/${v}_assembled.fasta
	else
		cp ${pathToMaSuRCAContig}/${v}_output/CA/9-terminator/genome.ctg.fasta ${outputFolder}/assembled_output/${v}_assembled.fasta
	fi
done
rm -r ${outputFolder}/quast_output
