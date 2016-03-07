package Models;

import java.io.File;
import java.io.FileWriter;
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
import java.util.StringTokenizer;

import javax.swing.JFrame;

import IHM.LoadingBar;
import IHM.Tools;

public class TractoModel {
	public static final String logFile = "logTractotron.txt"; 
	private String lesionDir;
	private String tractsDir;
	private File result;
	//The execution path of the software
	private String path;
	//The folder of the script
	private String exeDir;
	private LoadingBar loading;
	private FilenameFilter fileNameFilter;
	// The frame which will displays error and end messages 
	private JFrame frame;

	public TractoModel(String path, JFrame frame) {
		this.path = path;
		this.exeDir = path + "/Tools/scripts";
		this.frame = frame;
		
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
	}

	public void setLesionDir(String str) {
		lesionDir = str;
	}

	public void setTractsDir(String str) {
		tractsDir = str;
	}

	public void setResult(File f) {
		result = f;
	}
	
	public void setLoadingBar(LoadingBar load) {
		loading = load;
	}
	
	public void setNbTicks(int nb) {
		loading.setNbTicks(nb);
	}
	
	/**
	 * Execute the bash script TractotronParam.sh after verifying it is 
	 * executable by the user.
	 */
	public void run() {
		if (lesionDir == null) {
			throw new IllegalStateException(
					"You have to select the lesions directory");
		}
		if (tractsDir == null) {
			throw new IllegalStateException(
					"You have to select the tracts directory");
		}
		if (result == null) {
			throw new IllegalStateException(
					"You have to select the result file");
		}
				
		Boolean error = false;
		// On vide le fichier result. 
		try {
			FileWriter writer = new FileWriter(result, false); 
			writer.write("");
			writer.close();
		} catch (IOException e) {
			e.printStackTrace();
		}
		
		try {
			
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

		    Files.setPosixFilePermissions(Paths.get(exeDir + "/TractotronParam.sh"), perms);
			
			String[] array = {exeDir + "/TractotronParam.sh",
					lesionDir, tractsDir, result.getAbsolutePath()};

			Process proc = Runtime.getRuntime().exec(array, null, new File(this.path));
			
			Scanner out = new Scanner(proc.getInputStream());
			String tmp = "";
			int progress = 0;
			while (out.hasNextLine()) {
				tmp = out.nextLine();
				if (tmp.startsWith("#")) {
					StringTokenizer token = new StringTokenizer(tmp, "#\n");
					if (token.hasMoreTokens()) {
						setNbTicks(new File(lesionDir).listFiles(fileNameFilter).length
									* new File(tractsDir).listFiles(fileNameFilter).length);
					} else {
						progress++;
						loading.setWidth(progress);
					}
				} else {
					System.out.println(tmp);
				}
			}
			out.close();
			error = Tools.scriptError(proc, result.getParent(), logFile, frame);
			
        } catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		}
		if (!error) {
			Tools.showMessage(frame, "End !", "Data properly written in the result file");
		}
		return;
	}	
}
