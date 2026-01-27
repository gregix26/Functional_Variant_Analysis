Step 2: Run VEP as an initial step of functional annotation 

First, the VEP cache has to be downloaded: 
git clone https://github.com/Ensembl/ensembl-vep.git
cd ensembl-vep

To test that VEP is properly installed and working, run the following command in the ensmbl-vep folder: 
docker run --rm \
  -v /home/USER/data:/data \
  ensemblorg/ensembl-vep \
  vep --help | head

Then add execute permission to run_VEP.sh script with chmod +x  

The following packages also need to be installed for this step to work properly: 
biomaRt, data.table


In case ensembl server is down --> use convert_csvtovcf_robust.R script to connect to any of the servers