# Instructions for Tasci File Merger

## Installation
1. Install Ruby.
  - [http://rubyinstaller.org/](http://rubyinstaller.org/)
2. Install required gems.
        
        ```
            gem install activesupport
        ```
3. Download TASCI merger package zipfile from [Github](https://github.com/pmanko/tasci_merger) using the *Download ZIP* button.

4. Unpack to *package_directory*.

5. Run **IRB** in *package_directory*.

6. Load package.
        
        ```{Ruby}
            load('./tasci_merger.rb')
        ```
7. Generate master file list.

        ```{Ruby}
            tasci_merger = ETL::TasciMerger.new
            tm.create_master_list("TASCI_FILE_DIRECTORY", "OUTPUT_DIRECTORY")
        ```
8. Merge TASCI files.

        ```{Ruby}
            tm.merge_files(['SUBJECT_CODE'], "MASTER_FILE_PATH", "OUTPUT_DIRECTORY", "TASCI_FILE_DIRECTORY")
        ```
    
             

