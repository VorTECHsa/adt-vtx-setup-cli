[ ! -d "/Volumes/share" ] && echo "Not connected to VM SMB. Opening..." && open smb://user:password@vtx-setup-cli-test-vm.local/share
echo "\n--> Copying over to VM"
cp ./bash-poc.sh /Volumes/share || (echo "[!] Trying again in 3s..." && sleep 3 && cp ./bash-poc.sh /Volumes/share)
echo "Done!"
