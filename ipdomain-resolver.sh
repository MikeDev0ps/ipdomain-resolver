#!/bin/bash

remove_duplicates=false
csv_output=false
input_file=""
output_file=""

print_help() {
    echo "Usage: $0 [OPTIONS] [-f <input_file> | < <stdin>]"
    echo
    echo "DESCRIPTION:"
    echo "  This script processes a list of IP addresses, performs DNS lookups for each,"
    echo "  and outputs associated domain names. Optionally, it removes duplicate IPs,"
    echo "  formats output in CSV, and saves results to a specified file."
    echo
    echo "OPTIONS:"
    echo "  -f, --file <input_file>   Specify input file containing a list of IP addresses."
    echo "                            If omitted, input can be provided via pipe."
    echo
    echo "  -r, --remove-duplicates   Remove duplicate IP addresses from the input list."
    echo
    echo "  -o, --output <filename>   Save output to the specified file. Defaults to stdout."
    echo
    echo "      --csv                 Format output in CSV for Excel import. Includes"
    echo "                            IP and resolved domain names."
    echo
    echo "  -h, --help                Display this help message and exit."
    echo
    echo "USAGE EXAMPLES:"
    echo "  $0 -f ip_list.txt --remove-duplicates                # Process IPs from file, removing duplicates"
    echo "  cat ip_list.txt | $0 --csv                           # Process IPs from pipe, CSV output"
    echo "  $0 -f ip_list.txt -r --output results.txt            # Save deduplicated output to file"
    echo "  cat ip_list.txt | $0 -r --csv --output results.csv   # CSV output with deduplication, saved to file"
    echo
}

# Parsing command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--file)
            input_file="$2"
            shift 2
            ;;
        -r|--remove-duplicates)
            remove_duplicates=true
            shift
            ;;
        --csv)
            csv_output=true
            shift
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Determine input source (file or stdin)
if [[ -z "$input_file" && -t 0 ]]; then
    echo "Error: No input file provided and no data from stdin."
    echo "Use -f <input_file> or provide data through a pipe."
    print_help
    exit 1
fi

# Use stdin if no file is provided and there is piped input
if [[ -n "$input_file" ]]; then
    input_source="$input_file"
else
    input_source="/dev/stdin"
fi

# Temporary file to hold IPs for processing
temp_file=$(mktemp)

# Read IP addresses from the specified input source
while IFS= read -r ip; do
    if [[ -n "$ip" ]]; then
        echo "$ip" >> "$temp_file"
    fi
done < "$input_source"

# Remove duplicates if specified
if $remove_duplicates; then
    sort -u "$temp_file" -o "$temp_file"
fi

# Define output format
if $csv_output; then
    if [[ -n "$output_file" ]]; then
        exec > "$output_file"
    else
        echo "IP,Domain"
    fi
    while IFS= read -r ip; do
        domains=$(nslookup "$ip" | awk -F'= ' '/name =/ {print $2}')
        if [[ -n "$domains" ]]; then
            while IFS= read -r domain; do
                echo "$ip,$domain"
            done <<< "$domains"
        else
            echo "$ip,No domain found"
        fi
    done < "$temp_file"
else
    if [[ -n "$output_file" ]]; then
        exec > "$output_file"
    fi
    while IFS= read -r ip; do
        echo "$ip"
        domains=$(nslookup "$ip" | awk -F'= ' '/name =/ {print $2}')
        if [[ -n "$domains" ]]; then
            count=0
            total=$(echo "$domains" | wc -l)

            while IFS= read -r domain; do
                if [[ $((count + 1)) -eq "$total" ]]; then
                    echo "└── $domain"
                else
                    echo "├── $domain"
                fi
                count=$((count + 1))
            done <<< "$domains"
        else
            echo "└── No domain found"
        fi
    done < "$temp_file"
fi

# Clean up
rm "$temp_file"
