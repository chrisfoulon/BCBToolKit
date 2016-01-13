package Models;

import java.io.File;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.attribute.PosixFilePermission;
import java.util.HashSet;
import java.util.Scanner;
import java.util.Set;

import javax.swing.JFrame;

import Config.BCBEnum.Script;
import IHM.LoadingBar;
import IHM.Tools;

public class DiscoModel {
	public static final String logFile = "logDisconnectome.txt"; 
	private String lesionDir;
	private String resultDir;
	//The execution path of the software
	private String path;
	//The folder of the script
	private String exeDir;
	private String extraFiles;
	private LoadingBar loading;
	private JFrame frame;
	private FilenameFilter fileNameFilter;
	private FilenameFilter trkFilter;
	
	public DiscoModel(String path, JFrame f) {
		this.path = path;
		this.exeDir = path + "/Tools/scripts";
		this.extraFiles = path + "/Tools/extraFiles/Hypertron";
		this.frame = f;
		
		// create new filename filter to recognize .nii and .nii.gz files
        this.fileNameFilter = new FilenameFilter() {
           @Override
           public boolean accept(File dir, String name) {
        	  if (name.endsWith(".nii") || name.endsWith(".nii.gz")) {
        		  return true;
        	  } else {
        		  return false;
        	  }
           }
        };
        // create new filename filter to recognize .trk files
        this.trkFilter = new FilenameFilter() {
           @Override
           public boolean accept(File dir, String name) {
        	  if (name.endsWith(".trk")) {
        		  return true;
        	  } else {
        		  return false;
        	  }
           }
        };
	}
	
	public void setLesionDir(String str) {
		lesionDir = str;
	}
	
	public void setResultDir(String str) {
		resultDir = str;
	}

	public void setLoadingBar(LoadingBar load) {
		loading = load;
	}
	
	public void setNbTicks(int nb) {
		loading.setNbTicks(nb);
	}
	
	public void hyperRun() {
		if (lesionDir == null) {
			throw new IllegalStateException(
					"You have to select the lesions directory");
		}
		
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
		
		Boolean error = false;
		
		try {
			
			Files.setPosixFilePermissions(Paths.get(exeDir + Script.DISCONNECTOME.endPath()), perms);
			
			String[] array = {exeDir + Script.DISCONNECTOME.endPath(), lesionDir, resultDir};

			Process proc = Runtime.getRuntime().exec(array, null, new File(this.path));
			
			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			int nbTracks = new File(extraFiles).listFiles(trkFilter).length;
			setNbTicks(new File(lesionDir).listFiles(fileNameFilter).length * nbTracks);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);					
				}
			}
			out.close();
			error = Tools.scriptError(proc, resultDir, logFile, frame);
		
		} catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		}
		if (!error) {
			Tools.showMessage(frame, "End !", "Finished!!! Disconnectome maps saved in " + resultDir);
		}
		return;
	}
}
