package Models;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.attribute.PosixFilePermission;
import java.util.HashSet;
import java.util.Set;

import javax.swing.JFrame;

public abstract class AbstractModel {
	//The execution path of the software
	protected String path;
	//The folder of the script
	protected String script;
	// The frame which will displays error and end messages 
	protected JFrame frame;
	//We will make the process in attribute to handle the cancel action !
	Process proc = null;
	
	public AbstractModel(String path, JFrame f, String scriptName) {
		this.path = path;
		this.script = path + "/Tools/scripts" + scriptName;
		this.frame = f;
	}
	
	public void stopProcess() {
		if (proc != null) {
			proc.destroy();
			proc = null;
		}
	}

	public void permissions() {
		//On donne les droits d'exécution sur le script
		Set<PosixFilePermission> perms = new HashSet<PosixFilePermission>();
		// add owners permissions
		perms.add(PosixFilePermission.OWNER_READ);
		perms.add(PosixFilePermission.OWNER_WRITE);
		perms.add(PosixFilePermission.OWNER_EXECUTE);
		// add group permissions
		perms.add(PosixFilePermission.GROUP_READ);
		perms.add(PosixFilePermission.GROUP_EXECUTE);
		// add others permissions
		perms.add(PosixFilePermission.OTHERS_READ);
		perms.add(PosixFilePermission.OTHERS_EXECUTE);
		
		try {
			Files.setPosixFilePermissions(Paths.get(this.script), perms);
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}
	
}