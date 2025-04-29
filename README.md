

BigMilkAI is a customizable AI tool designed to process PDFs and answer questions about them. 
To start, download setup_bigmilkai.sh:
chmod +x setup_bigmilkai.sh
./setup_bigmilkai.sh

After that, go to the directory you selected (or $HOME/bigmilkai by default)
./bigmilkai_manager.sh

Below is the management menu available when running `./bigmilkai_manager.sh`:

### Management Menu

| Option | Description |
|--------|-------------|
| 1      | **Start Services**: Starts Ollama and Open WebUI. |
| 2      | **Stop Services**: Stops both services. |
| 3      | **Restart Services**: Restarts the services. |
| 4      | **Check Status**: Shows the status of services. |
| 5      | **View Logs**: Displays logs from the script, Ollama, and Open WebUI. |
| 6      | **Enable/Disable on Boot**: Configures auto-start on boot. |
| 7      | **Import PDF Base (CLI)**: Imports PDFs for training. |
| 8      | **Fine-Tune Model with PDFs**: Fine-tunes the model with PDFs. |
| 9      | **Convert and Import Fine-Tuned Model to Ollama**: Converts and imports the fine-tuned model. |
| 10     | **Install BigMilkAI**: Installs the environment and model. |
| 11     | **Uninstall BigMilkAI**: Removes everything from the system. |
| 12     | **Start Web Interface**: Starts the web interface at `localhost:5000`. |
| 13     | **Show Network Details**: Displays network information. |
| 0      | **Exit**: Exits the manager. |

To get started, run:
```bash
cd /path/to/bigmilkai
./bigmilkai_manager.sh

Run the Installer:
	chmod+x setup_bigmilkAI.sh
	./setup_bigmilkAI.sh

Default directory: $HOME/bigmilkai
	- If you want to use the defaulf, just press enter;
	- If you prefer another one, you can type what you need, the installer will check for permissions and proceed if everything is ok;
	- If got error, will ask you another path;

The installer will create the following structure:
	bigmilkai
	├── bigmilkai_manager.sh
	├── extract_pdf_text.py
	├── fine_tune_model.py
	├── modules
	│   ├── install.sh
	│   ├── model.sh
	│   ├── network.sh
	│   ├── services.sh
	│   ├── utils.sh
	│   └── web.sh
	├── process_pdfs.py
	└── web_interface.py
```

Contact: fernandofei [at] gmail [dot] com

Some videos with dry-run:

Installation:
https://youtu.be/s_m2yntbaSc

OpenWebUI
https://youtu.be/MWWIaMU8wKQ
	
