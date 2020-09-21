#!/bin/bash

## Run genome assembly pipeline

get_input () {
        # Function for doing getopts
	
	# Setting default number of threads as 4
	threads=4

        while getopts "t:g:p:o:q:v:h" option
        do
                case $option in
                        t) threads=$OPTARG;;
			p) pathToInputFiles=$OPTARG;;
                        g) genomeAssembler=$OPTARG;;
			o) outputFolder=$OPTARG;;
                        q) qualityControl=$OPTARG;;
                        h) info_usage=1;;
			v) verbose=$OPTARG;;
                        *) echo "Incorrect arguments used. Use -h to know about the arguments available."
                esac
        done
        
        if ((info_usage)); then
                echo -e "The script contains a Genome Assembly pipeline.\nRun the script in the following format after giving the script executable permission:\n./run_assembly.sh\nArguments available\n\t-p <Path to folder containing input fastq forward and backward reads annotated as <name>_1 and <name>_2 and are gzipped>\n\t-q\tPerform quality control and trimming\n\t-g <Specify genome assembler to use, with options as follows:\n\t\t1) a\tauto\n\t\t2) u\tUnicycler\n\t\t3) m\tMaSuRCA\n\t-o <Path to output folder>\n\t-t <Number of threads>\n\t-v \tVerbose mode\n\t-h\tPrint usage information"
                exit
        fi
}

check_files () {
        # Function for checking for presence of input files and output folder

        if ((verbose));then
                echo "Checking if input arguments are correct"
        fi
        if test -d "$pathToInputFiles"; then
                if ((verbose)); then
                        echo "Path: $pathToInputFiles exists"
                fi
		if [ "$(ls -A $pathToInputFiles | grep fq.gz)" ]; then
			:
		else
			echo "No fastq.gz files in $pathToInputFiles exist"
                	exit 1
		fi
	else
		echo "Path: $pathToInputFiles doesn't exist"
		exit 1
	fi

	if ((verbose));then
                echo "Checking if input arguments are correct"
        fi
        if test -d "$outputFolder"; then
                if ((verbose)); then
                        echo "Path: $outputFolder exists"
                fi
        else
                echo "Path: $outputFolder doesn't exist"
                exit 1
        fi
	IFS='=' read -a f<<< "$(sed -n '1p' config.txt)"
	unicycler_path=${f[1]}
	IFS='=' read -a f<<< "$(sed -n '2p' config.txt)"
	masurca_path=${f[1]}
	IFS='=' read -a f<<< "$(sed -n '3p' config.txt)"
	fastp_path=${f[1]}
	IFS='=' read -a f<<< "$(sed -n '4p' config.txt)"
        quast_path=${f[1]}
	if test -f "$unicycler_path"; then
                if ((verbose)); then
                        echo "Unicycler path  exists"
                fi
        else
                echo "Unicycler path doesn't exist"
                exit 1
        fi
	if test -f "$masurca_path"; then
                if ((verbose)); then
                        echo "MaSuRCA path exists"
                fi
        else
                echo "MaSuRCA path doesn't exist"
                exit 1
        fi
	if test -f "$fastp_path"; then
                if ((verbose)); then
                        echo "FASTp path exists"
                fi
        else
                echo "FASTp path doesn't exist"
                exit 1
        fi
	if test -f "$quast_path"; then
                if ((verbose)); then
                        echo "QUAST path exists"
                fi
        else
                echo "QUAST path doesn't exist"
                exit 1
        fi
}

quality_control () {
	if ((verbose)); then
                echo "\nExecuting quality control and trimming\nCreating folders for output:"
        fi
	mkdir ${outputFolder}/fastp_outputs
	mkdir ${outputFolder}/trimmed_reads
	ls ${pathToInputFiles} | grep _1.fq.gz | xargs -I gw basename -s _1.fq.gz gw | xargs -I gwa mkdir ${outputFolder}/fastp_outputs/gwa_report
	ls ${pathToInputFiles} | grep _1.fq.gz | xargs -I gw basename -s _1.fq.gz gw | xargs -I gwa ${fastp_path} -w ${threads} -i ${pathToInputFiles}/gwa_1.fq.gz -I ${pathToInputFiles}/gwa_2.fq.gz -5 -3 -W 10 -M 22 -c -o ${outputFolder}/trimmed_reads/gwa_trim_1.fq.gz --out2 ${outputFolder}/trimmed_reads/gwa_trim_2.fq.gz -j ${outputFolder}/fastp_outputs/gwa_report/fastp.json -h ${outputFolder}/fastp_outputs/gwa_report/fastp.html	
}

genome_assembly () {
	if ((verbose)); then
                echo "\nExecuting genome assembly with tool "
        fi

	if [ "$genomeAssembler" == "u" ]; then
		echo "Unicycler"
		if ((qualityControl)); then
                	bash run_unicycler.sh -p ${outputFolder}/trimmed_reads -o ${outputFolder} -m ${unicycler_path} -t ${threads} -v
        	else
                	bash run_unicycler.sh -p ${pathToInputFiles} -o ${outputFolder} -m ${unicycler_path} -t ${threads} -v
        	fi
	elif [ "$genomeAssembler" == "m" ]; then
		echo "MaSuRCA"
		if ((verbose)); then
                	echo "\nMaking output directory\n"
        	fi
		if ((qualityControl)); then
			if ((verbose)); then
                		echo "\nStarted genome assembly\n"
        		fi
			bash run_masurca.sh -p ${outputFolder}/trimmed_reads -o ${outputFolder} -m ${masurca_path} -t ${threads} -v
		else
                        if ((verbose)); then
                                echo "\nStarted genome assembly\n"
                        fi
			bash run_masurca.sh -p ${pathToInputFiles} -o ${outputFolder} -m ${masurca_path} -t ${threads} -v
                fi

	elif [ "$genomeAssembler" == "a" ]; then
		echo "Auto method\n"
		if ((qualityControl)); then
                        if ((verbose)); then
                                echo "\nStarted genome assembly\n"
                        fi

                        bash run_masurca.sh -p ${outputFolder}/trimmed_reads -o ${outputFolder} -m ${masurca_path} -t ${threads} -v
                	bash run_unicycler.sh -p ${outputFolder}/trimmed_reads -o ${outputFolder} -m ${unicycler_path} -t ${threads} -v
			bash run_quast.sh -q "${quast_path}" -p "${outputFolder}/trimmed_reads" -u "${outputFolder}/unicycler_output" -m "${outputFolder}/masurca_output/" -o "${outputFolder}" -t "${threads}"		
		else
                        if ((verbose)); then
                                echo "\nStarted genome assembly\n"
                        fi
                        bash run_masurca.sh -p ${pathToInputFiles} -o ${outputFolder} -m ${masurca_path} -t ${threads} -v
			bash run_unicycler.sh -p ${pathToInputFiles} -o ${outputFolder} -m ${unicycler_path} -t ${threads} -v
			bash run_quast.sh -q "${quast_path}" -p "${outputFolder}" -u "${outputFolder}/unicycler_output" -m "${outputFolder}/masurca_output/" -o "${outputFolder}" -t "${threads}"
                fi
	else
                echo "Wrong input option for genome assembler. Type -h option for help"
                exit 1
	fi
}
main() {
        # Function that defines the order in which functions will be called

        get_input "$@"
        check_files
	if ((qualityControl)); then
		quality_control
	fi
	genome_assembly	
}

# Calling the main function
main "$@"

