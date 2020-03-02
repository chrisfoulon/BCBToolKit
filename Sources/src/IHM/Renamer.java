package IHM;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
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

import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JPanel;

import Config.BCBEnum;

public class Renamer extends JPanel {
	private static final long serialVersionUID = 8472469599028088568L;

	private String exeDir;
	private String prefix;
	private Browser bro;
	private JButton addBut;
	private JButton rmBut;
	private JFrame frame;
	/**
	 * Create a Renamer that will be able to add/remove a prefix on all names 
	 * of a selected directory.
	 */
	public Renamer(String pre, String lab, JFrame frame, BCBToolKitIHM b) {
		super();
		this.prefix = pre;
		this.frame = frame;
		this.exeDir = b.getWD() + "/Tools/scripts/";

		bro = new Browser(frame, lab, BCBEnum.fType.DIR.a(), null, null, 300, b);
		addBut = new JButton("Add prefix");
		rmBut = new JButton("Remove prefix");
		placeComponents();
		createControllers();
	}

	public void placeComponents() {
		BorderLayout b = new BorderLayout(0, 0);
		this.setLayout(b);
		this.add(bro, BorderLayout.NORTH);
		JPanel p = new JPanel(new FlowLayout(FlowLayout.CENTER)); {
			p.add(addBut, BorderLayout.SOUTH);
			p.add(rmBut, BorderLayout.SOUTH);
		}
		this.add(p);
	}

	public void createControllers() {
		addBut.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				runScript("addPref.sh");
			}
		});

		rmBut.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				runScript("rmPref.sh");
			}
		});
	}

	//Tool
	public void runScript(String name) {
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

			Files.setPosixFilePermissions(Paths.get(exeDir + name), perms);

			String[] array = new String[]{exeDir + name, bro.getPath(), prefix};

			Process proc = Runtime.getRuntime().exec(array);
			
			Scanner out = new Scanner(proc.getInputStream());
			String tmp = "";
			while (out.hasNextLine()) {
				tmp = out.nextLine();
				System.out.println(tmp);
			}
			out.close();

			Scanner err = new Scanner(proc.getErrorStream());
			while (err.hasNextLine()) {
				erreur += err.nextLine() + "\n";
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
			return;
		}
	}
}
