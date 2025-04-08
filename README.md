# bigmilkAI

What’s the idea?

Install Ollama in a Podman container  
	Dependency verification  
	Error handling at each step  
	Clear diagnostic messages  
	Automatic recovery from common failures  
	Set up a complete web interface (Frontend + Backend)  
	Create an integrated logging system (chat and execution)  
	Configure systemd services for automatic startup  
	Open firewall ports  
	Generate easy-to-use management scripts  

Commands after installation:  
	Command | Description  
					--- | ---  
	`gerenciar-ia start` | Starts all services  
	`gerenciar-ia stop` | Stops all services (requires password)  
	`gerenciar-ia status` | Shows service status  
	`gerenciar-ia remove` | Completely removes everything (requires password)  
	`ver-logs-ia chat` | Displays question/answer history  
	`ver-logs-ia exec` | Displays server execution logs  

Included features:  
	- Modern web interface with PDF upload  
	- Interactive chat with the LLM model  
	- Complete User Management:  
	  - Create/edit/delete users  
	  - Role assignment (admin/user)  
	  - Password changes  
	  - Language selection  

Multi-Language Support:  
	- English, Portuguese, Spanish  
	- Easy to add more languages  
	- Language-specific UI elements  

Enhanced Admin Panel:  
	- Modern dark theme  
	- User management table  
	- Modals for user operations  
	- Navigation sidebar  

Improved Security:  
	- Proper password hashing  
	- Role-based access control  
	- Secure session management  

Detailed logs in JSON format  
	

Fully isolated in containers  

To use:  
	#chmod +x install.sh
	#./install.sh  

This is a complete, test-ready system, all in a single installation file and manager in the other!
