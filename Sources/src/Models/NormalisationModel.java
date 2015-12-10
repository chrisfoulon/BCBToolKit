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

public class NormalisationModel {
	private String tempFile;
	private String t1Dir;
	private String lesDir;
	private String resDir;
	//Other dir
	private String othDir;
	private String othRes;
	//The execution path of the software
	private String path;
	//The folder of the script
	private String exeDir;
	//The bet option value
	private String betOpt;
	//Should we save tempory files ? 
	private String saveTmp;
	private LoadingBar loading;
	private JFrame frame;
	private FilenameFilter fileNameFilter;
	
	public NormalisationModel(String path, JFrame f) {
		this.path = path;
		this.exeDir = path + "/Tools/scripts";
		this.frame = f;
		this.othDir = "";
		this.othRes = "";
		
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
	
	public void setT1Dir(String str) {
		t1Dir = str;
	}
	
	public void setTempFile(String str) {
		tempFile = str;
	}
	
	public void setLesionDir(String str) {
		lesDir = str;
	}
	
	public void setResultDir(String str) {
		resDir = str;
	}
	
	public void setOthDir(String str) {
		othDir = str;
	}
	
	public void setOthResDir(String str) {
		othRes = str;
	}
	
	public void setBetOpt(String str) {
		betOpt = str;
	}
	
	public void setSaveTmp(String str) {
		if (str == null || str.equals("") || (!str.equals("false") && !str.equals("true"))) {
			throw new IllegalArgumentException("The value of saveTmp must be true or false");
		}
		saveTmp = str;
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
	public void run(boolean other) {		
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
			
			Files.setPosixFilePermissions(Paths.get(exeDir + "/normalize.sh"), perms);
			
			String[] array;
			
			String betOptFinal = "0.5";
			if (!betOpt.equals("")) {
				betOptFinal = betOpt;
			}
			
			if (other) {
				 array = new String[]{exeDir + "/normalize.sh", t1Dir,
						 lesDir, resDir, tempFile, betOptFinal, saveTmp, othDir, othRes};
			} else {
				array = new String[]{exeDir + "/normalize.sh", t1Dir,
						 lesDir, resDir, tempFile, betOptFinal, saveTmp};
			}

			Process proc = Runtime.getRuntime().exec(array, null, new File(this.path));
			
			Scanner out = new Scanner(proc.getInputStream());
			int progress = 0;
			setNbTicks(new File(t1Dir).listFiles(fileNameFilter).length);
			while (out.hasNextLine()) {
				String inLoop = out.nextLine();
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
				String warn = "WARNING";
				String sigmas = "size of sigmas";
				if (tmp.toLowerCase().contains(warn.toLowerCase()) || 
						tmp.toLowerCase().contains(sigmas.toLowerCase()) ||
						tmp.equals("")) {
					//nothing !
				} else {
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
		if (!erreur.equals("")) {
			String message = "**** SCRIPT ERROR ****\n"
							 + erreur
							 + "**** SCRIPT ERROR END ****\n";
			Tools.showErrorMessage(frame, message);
			return;
		} else {
			String finish = "Finished!!! Normalisation saved in " + resDir;
			String str2 = ""; 
			if (other) {
				str2 = "Other transformation saved in " + othRes;
			}
			
			Tools.showMessage(frame, "End !", 
					"<html>" + finish + "<br />" + str2 + "</html>");
			return;
		}
	}
}
