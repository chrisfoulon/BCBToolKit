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

import IHM.LoadingBar;
import IHM.Tools;

public class StatisticalModel {
	private String map1Dir;
	private String map2Dir;
	private String resultDir;
	//The execution path of the software
	private String path;
	//The folder of the script
	private String exeDir;
	private LoadingBar loading;
	private JFrame frame;
	private FilenameFilter fileNameFilter;
	
	public StatisticalModel(String path, JFrame f) {
		this.path = path;
		this.exeDir = path + "/Tools/scripts";
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
	}
	
	public void setMap1Dir(String str) {
		map1Dir = str;
	}
	
	public void setMap2Dir(String str) {
		map2Dir = str;
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
	
	/*
	 * Fonction du bouton RUN si la checkBox hypertron est cochée. 
	 * On utilise un autre fichier de résultat car on a besoin d'un fichier texte et non
	 * d'un .xls. 
	 * On ne passait pas les chemins en paramètres donc on va rester cohérent avec le reste
	 * et utiliser les attributs. 
	 */
	public void hyperRun() {		
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
		
		String erreur = "";
		
		try {
			
			Files.setPosixFilePermissions(Paths.get(exeDir + "/test.r"), perms);
			
			String[] array = {exeDir + "/test.r", map1Dir, map2Dir, resultDir};
			//String[] array = {exeDir + "/test.r", "8", "8", "6", "1"};
			String[] array2 = {exeDir + "/preR.sh"};
			String[] array3 = {"/bin/bash", "type", "-p", "R"};
			Process rInstalled = Runtime.getRuntime().exec(array3, null, new File(this.path));
			Process proc = null;
			Scanner rOut = new Scanner(rInstalled.getInputStream());
			if (rOut.hasNextLine() && rOut.nextLine().equals("")) {
				System.out.println("R is not installed !!");
			} else {
				Process p = Runtime.getRuntime().exec(array2, null, new File(this.path));
				try {
					p.waitFor();
				} catch (InterruptedException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
				proc = Runtime.getRuntime().exec(array,  
						new String[]{"R_LIBS=" + this.path + "/Tools/installR"}, new File(this.path));
			}
			rOut.close();
			
			Scanner out = new Scanner(proc.getInputStream());
			//String tmp = "";
			int progress = 0;
			// Le script renvoi 5 # par patient
			setNbTicks(new File(map1Dir).listFiles(fileNameFilter).length);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
				/*
				 * Attention la boucle augmente la barre de progression plusieurs fois par patient
				 * car le calcul est long et je voudrais bien que l'on voit quelques chose pendant les 
				 * calculs même pour une seul patient 
				 */
				if (inLoop.startsWith("#")) {
					progress++;
					loading.setWidth(progress);					
				}
				System.out.println(inLoop);
			}
			out.close();
			Scanner err = new Scanner(proc.getErrorStream());
			while (err.hasNextLine()) {
				String tmp = err.nextLine();
				if (!tmp.startsWith("oro.nifti") && !tmp.startsWith("plyr")) {
					erreur += tmp + "\n";				
				} 
			}
			err.close();
		
		} catch (IOException e) {
			Writer writer = new StringWriter();
			PrintWriter printWriter = new PrintWriter(writer);
			e.printStackTrace(printWriter);
			String s = writer.toString();
			Tools.showErrorMessage(frame, s);
			return;
		}
		if (erreur != "") {
			String message = "**** SCRIPT ERROR ****\n"
							 + erreur
							 + "**** SCRIPT ERROR END ****\n";
			Tools.showErrorMessage(frame, message);
			return;
		} else {
			Tools.showMessage(frame, "End !", "Finished!!! Results saved in " + resultDir);
			return;
		}
	}
}
