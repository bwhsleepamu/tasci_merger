# Instructions for Tasci File Merger

## Installation
1. Install Ruby.
  - [http://rubyinstaller.org/](http://rubyinstaller.org/)
  - Download Ruby 2.1.5 (x64) installer.
  - Install to desired *RUBY_DIRECTORY*
  - Choose option to add ruby to *PATH*
  - Choose option to associate *.rb files with Ruby

2. Verify ruby installation.
  - Go into command line.
  - Enter `ruby -v`
  - Ouput should look like `ruby 2.1.5p273...`
  - Enter `gem -v`
  - Output should look like `2.2.2`

3. Fix potential RubyGems certificate bug, as documented on [this page](https://gist.github.com/luislavena/f064211759ee0f806c88)
  - Try running `gem install activesupport --no-ri --no-rdoc`
  - Click `Allow access` if prompted by Windows Firewall message, choosing option for *Private networks*
  - If installation fails with an `SSL_error`, follow the following steps:
    - Save certificate file from [this website](https://raw.githubusercontent.com/rubygems/rubygems/master/lib/rubygems/ssl_certs/AddTrustExternalCARoot-2048.pem) to the Downloads directory.
    - **Make sure file is saved with the *.pem extension**
    - Find rubygems folder location by typing `gem which rubygems` into the console. You should get output like `C:/Ruby21/lib/ruby/2.1.0/rubygems.rb`
    - Locate the directory and open it in an explorer window. For the above path, the directory would be `C:\Ruby21\lib\ruby\2.1.0\rubygems`
    - Open the `ssl_certs` directory, and copy the previously-downloaded `*.pem` file into this directory.
    - Close and re-open a console window.

4. Install required gems.
  - Run:

    ```
      gem install activesupport --no-ri --no-rdoc
      gem install 'tzinfo-data' --no-ri --no-rdoc
    ```
5. Download TASCI merger package zipfile from [Github](https://github.com/pmanko/tasci_merger) using the *Download ZIP* button.

10. Merge TASCI files.
6. Unpack to *package_directory*.

7. Run **IRB** in *package_directory*.
  - Open console
  - Run `cd unpacked_package_directory` to navigate to package directory
  - Run `irb` to open interactive ruby console

8. Load package.
        
  ```ruby
    load('./tasci_merger.rb')
  ```
9. Generate master file list.

  ```ruby
    tasci_merger = ETL::TasciMerger.new
    tasci_merger.create_master_list("TASCI_FILE_DIRECTORY", "OUTPUT_DIRECTORY")
  ```

  ```ruby
    tm.merge_files(['SUBJECT_CODE'], "MASTER_FILE_PATH", "OUTPUT_DIRECTORY", "TASCI_FILE_DIRECTORY")
  ```
    
             

