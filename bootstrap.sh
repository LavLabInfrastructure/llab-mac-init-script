#!/bin/bash
# system level installs missing LaViolette Lab utilities 
# MATLAB/SPM, Horos, Illustrator, Endnote, Citrix? require manual install due to licensing

# freesurfer requires getting a free license
[[ $(arch) =~ ^arm ]] && arm=true || arm=false
here=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "mjbarrett      ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/bootstrap >/dev/null

export PAGER=cat

# add developer folder
sudo mkdir -p /System/Library/User\ Template/English.lproj/English.lproj/Developer

# get rosetta if not already installed
[[ $arm == true ]] && /usr/sbin/softwareupdate --install-rosetta --agree-to-license


# matlab goodies

MATLAB_GLOBAL_SCRIPT_DIR=/etc/matlab
[[ ! -d $MATLAB_GLOBAL_SCRIPT_DIR ]] &&
    sudo mkdir -p $MATLAB_GLOBAL_SCRIPT_DIR/omero &&
    curl -qLo /tmp/omero_matlab.zip "https://github.com/ome/omero-matlab/releases/download/v5.5.6/OMERO.matlab-5.5.6.zip" &&
    sudo unzip -d $MATLAB_GLOBAL_SCRIPT_DIR/omero /tmp/omero_matlab.zip
    echo '
#### MATLAB ####
export MATLAB_GLOBAL_SCRIPT_DIR=/etc/matlab' | sudo tee /etc/zshenv >/dev/null


# install brew if missing (Latest:Native)
[[ -z $(brew --version 2> /dev/null; exit 0) ]] && echo "Installing Brew!" &&
    echo | /bin/bash -c "$(curl -fJsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" &&
    echo '
#### BREW PACKAGE MANAGER ####
export HOMEBREW_PREFIX="/opt/homebrew";
export HOMEBREW_CELLAR="/opt/homebrew/Cellar";
export HOMEBREW_REPOSITORY="/opt/homebrew";' | sudo tee /etc/zshenv >/dev/null
echo '
#### BREW PACKAGE MANAGER ####
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}";
export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:";
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";' | sudo tee /etc/zshrc >/dev/null

# check brew is healthy
brew update || (echo "Brew is not working correctly! Closing..." && exit 1)

# do the same for an x86_64 brew install if required and not installed
if [[ $arm == true ]] 
then
    if [[ -z $(brew_64 --version 2> /dev/null; exit 0) ]]
    then
        echo | arch -x86_64 /bin/bash -c "$(curl -fJsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        echo '
#### BREW PACKAGE MANAGER ####
alias brew_arm=/opt/homebrew/bin/brew
alias brew_64="arch -x86_64 /usr/local/Homebrew/bin/brew"' | sudo tee /etc/lavlab-aliases >/dev/null
    else
        brew_64 update || 
            (echo "Brew is not working correctly! Closing..." && exit 1)
    fi
    brew_64="arch -x86_64 /usr/local/Homebrew/bin/brew"
    brew=/opt/homebrew/bin/brew
else
    brew=brew
fi

# force newest xquartz
$brew reinstall --cask xquartz

# best text editors
$brew install vim emacs

# python2 
# $brew install python && python2=/usr/local/bin/python 
# [[ $arm == true ]] && $brew install python  && echo '
# #### PYTHON2 ####
# python2=/opt/homebrew/bin/python
# python2_arm=/opt/homebrew/bin/python
# python2_64=/usr/local/bin/python
# # not gonna make it easy for people to accidentally use python2
# python=python3' | sudo tee /etc/lavlab-aliases >/dev/null || echo '
# #### PYTHON2 ####
# python2=/usr/local/bin/python
# # not gonna make it easy for people to accidentally use python2
# python=python3' | sudo tee /etc/lavlab-aliases >/dev/null

# get all available python versions and x86 counterparts if necessary
for i in {7..11}; do 
    [[ -z $(python3.${i} --version 2> /dev/null; exit 0) ]] && $brew install python@3.${i}
    [[ $arm == true ]] && [[ -z $(python3.${i}_64 --version 2> /dev/null; exit 0) ]] && 
        arch -x86_64 /usr/local/Homebrew/bin/brew install python@3.${i} &&
        alias python3.${i}_64="arch -x86_64 /usr/local/Homebrew/bin/python3.${i}" &&
        echo "
#### PYTHON3.${i} ####
alias python3.${i}_arm=/opt/homebrew/bin/python3.${i}
alias python3.${i}_64=\"arch -x86_64 /usr/local/Homebrew/bin/python3.${i}\"" | sudo tee /etc/lavlab-aliases >/dev/null
done

# bash_64 is pretty important
[[ $arm == true ]] && arch -x86_64 /usr/local/Homebrew/bin/brew install bash &&
    alias bash_64="arch -x86_64 /usr/local/Homebrew/bin/bash" &&
    echo '
#### BASH ####
alias bash_arm=/bin/bash
alias bash_64="arch -x86_64 /usr/local/Homebrew/bin/bash"' | sudo tee /etc/lavlab-aliases >/dev/null


# install R(6/13/23:Native) and Fortran(6/13/23:Universal) if missing
if [[ -z $(r --version 2> /dev/null; exit 0) ]] 
then
    echo "Installing R!"  
    [[ $arm == true ]] && 
        curl -qJLo /tmp/R.nn.pkg "https://cran.r-project.org/bin/macosx/big-sur-arm64/base/R-4.3.0-arm64.pkg" ||
        curl -qJLo /tmp/R.nn.pkg "https://cran.r-project.org/bin/macosx/big-sur-x86_64/base/R-4.3.0-x86_64.pkg"
    sudo installer -pkg /tmp/R.nn.pkg -target /
    export PATH=$PATH:/Library/Frameworks/R.framework/Resources 

    echo "Installing Fortran Compiler!"
    curl -qJLo /tmp/gfortran.pkg "https://mac.r-project.org/tools/gfortran-12.2-universal.pkg"
    sudo installer -pkg /tmp/gfortran.pkg -target /
    export PATH=$PATH:/usr/local/gfortran/bin 
    echo '
#### R & FORTRAN ####
export PATH=$PATH:/Library/Frameworks/R.framework/Resources/bin
export PATH=$PATH:/usr/local/gfortran/bin' | sudo tee /etc/zshrc >/dev/null
    echo 'alias r=/Library/Frameworks/R.framework/Resources/bin/R' | sudo tee /etc/lavlab-aliases >/dev/null
fi

# install FSL(Latest:Universal) if missing (CONTAINS MINICONDA)  
if [[ -z $(flirt -version 2> /dev/null; exit 0) ]] 
then 
    echo "Installing FSL!"
    curl -qJLo /tmp/installFSL.py "https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/fslinstaller.py"
    chmod +x /tmp/installFSL.py 
    echo | sudo arch -x86_64 /usr/local/bin/python3 /tmp/installFSL.py -d /usr/local/fsl
    FSL=true
    echo '
#### FSL ####
export FSLDIR=/usr/local/fsl' | sudo tee /etc/zshenv >/dev/null
    echo '
#### FSL ####
export PATH=${FSLDIR}/share/fsl/bin:${PATH}
. ${FSLDIR}/etc/fslconf/fsl.sh' | sudo tee /etc/zshrc >/dev/null
    echo '
%%%% FSL %%%%
addpath(genpath(getenv('MATLAB_GLOBAL_SCRIPT_DIR')));
setenv( 'FSLDIR', '/usr/local/fsl' );
setenv('FSLOUTPUTTYPE', 'NIFTI_GZ');
fsldir = getenv('FSLDIR');
fsldirmpath = sprintf('%s/etc/matlab',fsldir);
path(path, fsldirmpath);
clear fsldir fsldirmpath;' | sudo tee /etc/matlab/startup.m > /dev/null
else
    echo "FSL already installed!"
fi

# install AFNI(Latest:Universal) if missing 
if [[ -z $(afni --version 2> /dev/null; exit 0) ]] 
then
    echo "Installing AFNI!"
    # install dependencies
    $brew install netpbm cmake 
    Rscript -e "install.packages(c('afex','phia','snow','nlme','lmerTest'), repos='https://cloud.r-project.org')"
    curl -sJo /tmp/update.afni.binaries "https://afni.nimh.nih.gov/pub/dist/bin/misc/@update.afni.binaries"
    sudo tcsh /tmp/update.afni.binaries -bindir /usr/local/afni -package macos_10.12_local -do_extras
    echo '
#### AFNI ###    
export PATH=$PATH:/usr/local/afni
# export PATH=$PATH:/usr/local/bin/python  python dependecy for afni, 
export DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}:/opt/X11/lib/flat_namespace'  | sudo tee /etc/zshrc >/dev/null
    echo "Finished installing AFNI!"

    #install confirmation 
    echo "RUNNING AFNI INSTALL CHECKER"
    /usr/local/afni/afni_system_check.py -check_all > ./afni-install-verification.txt
    AFNI=true
else 
    echo "AFNI already installed!"
fi

# install FreeSurfer(6/13/23:Universal) if missing 
freesurfer_url="https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.4.0/freesurfer-darwin-macOS-7.4.0.tar.gz"
if [[ -z $(freesurfer --version 2> /dev/null; exit 0) ]]
then
    echo "Installing FreeSurfer!"
    curl -qJLo /tmp/freesurfer.tar.gz $freesurfer_url
    sudo mkdir -p /usr/local/freesurfer/7.4.0
    sudo tar -zxvpf /tmp/freesurfer.tar.gz -C /usr/local/freesurfer/7.4.0
    
    echo '
#### FREESURFER #### (see /usr/local/freesurfer/FreeSurferEnv.sh)
export FREESURFER_HOME=/usr/local/freesurfer/7.4.0' | sudo tee /etc/zshenv >/dev/null
    echo '
#### FREESURFER #### (see /usr/local/freesurfer/SetUpFreeSurfer.sh)
FS_FREESURFERENV_NO_OUTPUT=true 
source $FREESURFER_HOME/SetUpFreeSurfer.sh' | sudo tee /etc/zshrc >/dev/null
    echo "Installed FreeSurfer!" 
    FREESURFER=true 
else
    echo "FreeSurfer already installed!"
fi

# install 3dSlicer(Latest:Universal) if missing
if [[ -z $(Slicer 2> /dev/null; exit 0) ]] 
then
    echo "Installing 3DSlicer!"
    $brew tap homebrew/cask-versions
    $brew install --cask slicer
    echo "Installed 3DSlicer!"
    SLICER=true 
else
    echo "Slicer already installed!"
fi

# install Docker(Latest:Native)
if [[ ! -d "/Applications/Docker.app" ]]
then
    echo "Installing Docker!"
    [[ $arm == true ]] && 
        curl -qJLo /tmp/Docker.dmg "https://desktop.docker.com/mac/main/arm64/Docker.dmg" ||
        curl -qJLo /tmp/Docker.dmg "https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    sudo hdiutil attach /tmp/Docker.dmg
    sudo /Volumes/Docker/Docker.app/Contents/MacOS/install
    sudo hdiutil detach /Volumes/Docker
    sudo osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Docker.app", hidden:false}'
fi

# install ITK-SNAP(6/13/23:Native) if missing
if [[ ! -d "/Applications/ITK-SNAP.app" ]]
then
    echo "Installing ITK-SNAP!"
    if [[ $arm == true ]] 
    then
        curl -qJLo /tmp/itk.dmg "https://sourceforge.net/projects/itk-snap/files/itk-snap/4.0.1/itksnap-4.0.1-20230320-Darwin-arm64.dmg/download"
        echo "Y" | hdiutil attach /tmp/itk.dmg
        sudo cp -r /Volumes/itksnap-4.0.1-20230320-Darwin-arm64/ITK-SNAP.app /Applications
        hdiutil detach /Volumes/itksnap-4.0.1-20230320-Darwin-arm64
    else
        curl -qJLo /tmp/itk.dmg "https://sourceforge.net/projects/itk-snap/files/itk-snap/4.0.1/itksnap-4.0.1-20230320-Darwin-x86_64.dmg/download"
        echo "Y" | hdiutil attach /tmp/itk.dmg
        sudo cp -r /Volumes/itksnap-4.0.1-20230320-Darwin-x86_64/ITK-SNAP.app /Applications
        hdiutil detach /Volumes/itksnap-4.0.1-20230320-Darwin-x86_64
    fi
    echo '
#### ITK-SNAP ####
export PATH=$PATH:/Applications/ITK-SNAP.app/Contents/bin/' | sudo tee /etc/zshrc >/dev/null
else
    echo "ITK-SNAP is already installed!"
fi

# install Blender(06/13/23:Native) if missing
if [[ ! -d "/Applications/Blender.app" ]]
then
    echo "Installing Blender!"
    [[ $arm == true ]] &&
        curl -qJLo /tmp/blender.dmg "https://mirror.clarkson.edu/blender/release/Blender3.5/blender-3.5.1-macos-arm64.dmg" ||
        curl -qJLo /tmp/blender.dmg "https://mirror.clarkson.edu/blender/release/Blender3.5/blender-3.5.1-macos-x64.dmg"
    echo "Y" | hdiutil attach /tmp/blender.dmg
    sudo cp -r /Volumes/Blender/Blender.app /Applications
    echo 'alias blender=/Applications/Blender.app/Contents/MacOS/Blender' | sudo tee /etc/lavlab-aliases
    hdiutil detach /Volumes/Blender/
else
    echo "Blender already installed!"
fi

# install Makerbot Desktop(Deprecated:Universal) if missing
if [[ ! -d "/Applications/MakerBot.app" ]]
then
    echo "Installing MakerBot Desktop!"
    curl -qJLo /tmp/makerbot.dmg "https://s3.amazonaws.com/downloads-makerbot-com/makerware/MakerBot+Bundle+BETA+3.10.1.1746.dmg"
    echo "Y" | hdiutil attach /tmp/makerbot.dmg
    sudo installer -pkg /Volumes/MakerBot\ Bundle\ BETA/MakerBot\ Bundle\ BETA\ 3.10.1.1746.pkg -target /
    hdiutil detach /Volumes/MakerBot\ Bundle\ BETA/
else
    echo "MakerBot Desktop Already Installed!"
fi

# install MakerBot Print(6/13/23:Universal) if missing
if [[ ! -d "/Applications/MakerBot Print.app" ]]
then
    echo "Installing MakerBot Print!"
    curl -qJLo /tmp/mb-print.pkg "https://s3.amazonaws.com/makerbot-desktop-4.0/installer/prerelease/4.3.0.7434/MakerBotPrintInstaller.pkg"
    sudo installer -pkg /tmp/mb-print.pkg -applyChoiceChangesXML $here/makerbox.xml -target /
else
    echo "MakerBot Print Already installed!"
fi

# install IdeaMaker(6/13/23:Native) if missing
if [[ ! -d "/Applications/ideaMaker.app" ]]
then
    echo "Installing ideaMaker!"
    [[ $arm == true ]] &&
        curl -qJLo /tmp/ideamaker.dmg "https://download.raise3d.com/ideamaker/release/4.3.2/install_ideaMaker_4.3.2.6470-arm64.dmg" || 
        curl -qJLo /tmp/ideamaker.dmg "https://download.raise3d.com/ideamaker/release/4.3.2/install_ideaMaker_4.3.2.6470.dmg"
    echo "Y" | hdiutil attach /tmp/ideamaker.dmg
    sudo cp -r /Volumes/Install\ ideaMaker\ 4.3.2.6470/ideaMaker.app /Applications
    hdiutil detach /Volumes/Install\ ideaMaker\ 4.3.2.6470/
else
    echo "ideaMaker already installed!"
fi

# install PreForm(6/13/23:Universal) if missing
if [[ ! -d "/Applications/PreForm.app" ]]
then
    echo "Installing PreForm!"
    curl -qJLo /tmp/preform.dmg "https://downloads.formlabs.com/PreForm/Release/3.29.1/PreForm_mac_3.29.1_release_releaser_213_37481.dmg"
    echo "Y" | hdiutil attach /tmp/preform.dmg
    sudo cp -r /Volumes/PreForm/PreForm.app /Applications
    hdiutil detach /Volumes/PreForm
else
    echo "PreForm already Installed!"
fi

# install VSCode(Latest:Native) if missing
if [[ ! -d "/Applications/Visual Studio Code.app" ]]
then
    echo "Installing VSCode!"
    [[ $arm == true ]] && 
        sudo curl -qJLo /tmp/vscode.zip "https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64" ||
        sudo curl -qJLo /tmp/vscode.zip "https://code.visualstudio.com/sha/download?build=stable&os=darwin"
    unzip /tmp/vscode.zip -d /Applications
    echo '
#### Visual Studio Code #### 
PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' | sudo tee /etc/zshrc >/dev/null
    
    # install extensions and dependencies for those extensions
    Rscript -e 'install.packages("languageserver")'
    Rscript -e 'install.packages("httpgd")'

    while read p; do
    /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code --install-extension $p
    done <$here/vscode-extensions.txt

fi

# install Chrome(Latest:Native?) if missing
if [[ ! -d "/Applications/Google Chrome.app" ]]
then
    echo "Installing Google Chrome"
    [[ $arm == true ]] &&
        curl -qJLo /tmp/chrome.dmg "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg" ||
        curl -qJLo /tmp/chrome.dmg "https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
    echo "Y" | hdiutil attach /tmp/chrome.dmg
    sudo cp -r /Volumes/Google\ Chrome/Google\ Chrome.app /Applications
    hdiutil detach /Volumes/Google\ Chrome/
    CHROME=true
else
    echo "Chrome is already installed!"
fi

# install Microsoft 365(Latest:Universal) if missing
if [[ ! -d "/Applications/Microsoft Excel.app" ]]
then 
    echo "Installing Microsoft Office!"
    curl -qJLo /tmp/office.pkg "https://go.microsoft.com/fwlink/p/?linkid=2009112"
    sudo installer -pkg /tmp/office.pkg -target /
    OFFICE=true
else
    echo "Microsoft Office already installed!"
fi

# install Adobe Acrobat(6/13/23) BROKEN CANNOT GET RAW FILE LINK
# if [[ ! -d "/Applications/Adobe Acrobat Reader DC.app" ]]
# then
#     echo "Installing Adobe Acrobat!"
#     curl -qJLO "https://get.adobe.com/reader/download?os=Mac+OS+10.15.7&name=Reader+DC+2023.003.20201+for+Mac&lang=en&nativeOs=Mac+OS+10.15.7"
#     echo "Y" | hdiutil attach ./AcroRdrDC_2300320201_MUI.dmg
#     sudo installer -pkg /Volumes/AcroRdrDC_2300320201_MUI/AcroRdrDC_2300320201_MUI.pkg -target /
#     hdiutil detach /Volumes/AcroRdrDC_2300320201_MUI
# else
#     echo "Adobe Acrobat already installed!"
# fi

# install Webex(Latest:Native)
if [[ ! -d "/Applications/Webex.app" ]]
then
    echo "installing webex"
    [[ $arm == true ]] &&
        curl -qJLo /tmp/webex.dmg "https://binaries.webex.com/WebexDesktop-MACOS-Apple-Silicon-Gold/Webex.dmg" ||
        curl -qJLo /tmp/webex.dmg "https://binaries.webex.com/WebexTeamsDesktop-MACOS-Gold/Webex.dmg"
    echo "Y" | hdiutil attach /tmp/webex.dmg
    sudo cp -r /Volumes/Webex/Webex.app /Applications
    hdiutil detach /Volumes/Webex
else
    echo "webex already installed!"
fi

# install Zoom(Lastest:Native)
if [[ ! -d "/Applications/zoom.us.app" ]]
then
    echo "installing zoom"
    [[ $arm == true ]] &&
        curl -qJLo /tmp/zoom.pkg "https://zoom.us/client/5.14.10.19202/zoomusInstallerFull.pkg?archType=arm64" ||
        curl -qJLo /tmp/zoom.pkg "https://zoom.us/client/5.14.10.19202/zoomusInstallerFull.pkg"
    sudo installer -pkg /tmp/zoom.pkg -target /
else 
    echo "Zoom already installed!"
fi

# install Lab Development Suite(Latest@python3.9:Native)
venv_PYTHON=3.9
if [[ ! -d "/opt/lavlab-venv" ]]
then
    echo "Installing python goodies!"
    [[ -z $(python${venv_PYTHON} --version 2> /dev/null; exit 0) ]] && brew install python@${venv_PYTHON}
    sudo python${venv_PYTHON} -m venv /opt/lavlab-native

    [[ $arm == true ]] && # (Deprecated@python3.9:Native)
        curl -qJLo /tmp/ice_36.tar.bz2 "https://anaconda.org/conda-forge/zeroc-ice/3.6.5/download/osx-arm64/zeroc-ice-3.6.5-py39ha29907a_4.tar.bz2" || 
        curl -qJLo /tmp/ice_36.tar.bz2 "https://anaconda.org/conda-forge/zeroc-ice/3.6.5/download/osx-64/zeroc-ice-3.6.5-py39h41db984_4.tar.bz2"
    sudo tar -xf /tmp/ice_36.tar.bz2 -C /opt/lavlab-native

    sudo  /opt/lavlab-native/bin/python${venv_PYTHON} -m pip install --upgrade pip
    sudo  /opt/lavlab-native/bin/python${venv_PYTHON} -m pip install lavlab-python-utils
    sudo  /opt/lavlab-native/bin/python${venv_PYTHON} -m pip install numpy "pandas[excel]" SimpleITK pyradiomics

    # pytorch, tensorflow
    sudo  /opt/lavlab-native/bin/python${venv_PYTHON} -m pip install tensorflow==2.13.0rc1
    sudo  /opt/lavlab-native/bin/python${venv_PYTHON} -m pip install tensorflow-metal
    sudo  /opt/lavlab-native/bin/python${venv_PYTHON} -m pip install torch torchvision torchaudio
fi    

# all lab users should be admins, allow any admin to use all programs
# sudo chgrp -R admin /Applications/*
sudo chgrp -R admin /usr/local/*
sudo chgrp -R admin /opt/*
# sudo chmod -R g+w /Applications/*
sudo chmod -R g+w /usr/local/*
sudo chmod -R g+w /opt/*

# add all new login apps to defaults
sudo mkdir -p /System/Library/User\ Template/English.lproj/Application\ Support/com.apple.backgroundtaskmanagementagent
sudo cp ~/Library/Application\ Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm /System/Library/User\ Template/English.lproj/Application\ Support/com.apple.backgroundtaskmanagementagent

echo ". /etc/lavlab-aliases" | sudo tee /etc/zshrc >/dev/null

sudo rm /etc/sudoers.d/bootstrap

echo "Installations complete! Printing usage info for newly installed programs into ./llab-help.txt"

# [[ $BREW ]] && 
#     echo "brew --help:\n$(brew --help)\n" >> ./llab-help.txt

# [[ $PYTHON ]] && 
#     echo "python3 --help:\n$(python3 --help)\n" >> ./llab-help.txt

# [[ $FSL ]] && 
#     echo "Start FSL in gui-mode by running 'fsl' in a terminal.\n Check out https://fsl.fmrib.ox.ac.uk/fsl/fslwiki for more info\n" >> ./llab-help.txt

# [[ $AFNI ]] && 
    # echo "Start AFNI in gui-mode by running 'afni' in a terminal.\nafni -help:\n$(afni -help)\n"