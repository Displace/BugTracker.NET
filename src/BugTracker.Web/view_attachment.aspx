<%@ Page language="C#" CodeBehind="view_attachment.aspx.cs" Inherits="btnet.view_attachment" AutoEventWireup="True" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

//Copyright 2002-2011 Corey Trager
//Distributed under the terms of the GNU General Public License

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
    if (string.IsNullOrEmpty(Request["bug_id"]))
    {
        // This is to prevent exceoptions and error emails from getting triggered
        // by "Microsoft Office Existence Discovery".  Google it for more info.
        Response.End();
    }
	
	string bp_id = btnet.Util.sanitize_integer(Request["id"]);
	string bug_id = btnet.Util.sanitize_integer(Request["bug_id"]);

	var sql = new SQLString(@"
select bp_file, isnull(bp_content_type,'') [bp_content_type] 
from bug_posts 
where bp_id = @bp_id 
and bp_bug = @bug_id");

	sql = sql.AddParameterWithValue("bp_id", bp_id);
	sql = sql.AddParameterWithValue("bug_id", bug_id);

	DataRow dr = btnet.DbUtil.get_datarow(sql);

	if (dr == null)
	{
		Response.End();
	}
	
	int permission_level = Bug.get_bug_permission_level(Convert.ToInt32(bug_id), User.Identity);
	if (permission_level ==PermissionLevel.None)
	{
		Response.Write("You are not allowed to view this item");
		Response.End();
	}

	string var = Request["download"];
	bool download;
	if (var == null || var == "1")
	{
		download=true;
	}
	else
	{
		download=false;
	}


	string filename = (string) dr["bp_file"];
	string content_type = (string) dr["bp_content_type"];

    // First, try to find it in the bug_post_attachments table.
    var directSQL = @"select bpa_content
            from bug_post_attachments
            where bpa_post = @bp_id";

    bool foundInDatabase = false;
    String foundAtPath = null;
    using (SqlCommand cmd = new SqlCommand(directSQL))
    {
        cmd.Parameters.AddWithValue("@bp_id", bp_id);

        // Use an SqlDataReader so that we can write out the blob data in chunks.

        using (SqlDataReader reader = btnet.DbUtil.execute_reader(cmd, CommandBehavior.CloseConnection | CommandBehavior.SequentialAccess))
        {
            if (reader.Read()) // Did we find the content in the database?
            {
                foundInDatabase = true;
            }
            else
            {
				// Otherwise, try to find the content in the UploadFolder.

				string upload_folder = Util.get_upload_folder();
				if (upload_folder != null)
				{
					StringBuilder path = new StringBuilder(upload_folder);
					path.Append("\\");
					path.Append(bug_id);
					path.Append("_");
					path.Append(bp_id);
					path.Append("_");
					path.Append(filename);

					if (System.IO.File.Exists(path.ToString()))
					{
						foundAtPath = path.ToString();
					}
				}
			}

			// We must have found the content in the database or on the disk to proceed.

			if (!foundInDatabase && foundAtPath == null)
			{
				Response.Write("File not found:<br>" + filename);
				return;
			}

			// Write the ContentType header.

			if (string.IsNullOrEmpty(content_type))
			{
				Response.ContentType = btnet.Util.filename_to_content_type(filename);
			}
			else
			{
				Response.ContentType = content_type;
			}


			if (download)
			{
				Response.AddHeader ("content-disposition","attachment; filename=\"" + filename + "\"");
			}
			else
			{
				Response.Cache.SetExpires(DateTime.Now.AddDays(3));
				Response.AddHeader ("content-disposition","inline; filename=\"" + filename + "\"");
			}

			// Write the data.

			if (foundInDatabase)
			{
				long totalRead = 0;
				long dataLength = reader.GetBytes(0, 0, null, 0, 0);
				byte[] buffer = new byte[16 * 1024];

				while (totalRead < dataLength)
				{
					long bytesRead = reader.GetBytes(0, totalRead, buffer, 0, (int)Math.Min(dataLength - totalRead, buffer.Length));
					totalRead += bytesRead;

					Response.OutputStream.Write(buffer, 0, (int)bytesRead);
				}
			}
			else if (foundAtPath != null)
			{
				if (Util.get_setting("UseTransmitFileInsteadOfWriteFile", "0") == "1")
				{
					Response.TransmitFile(foundAtPath);
				}
				else
				{
					Response.WriteFile(foundAtPath);
				}
			}
			else
			{
				Response.Write("File not found:<br>" + filename);
			}

		} // end using sql reader
	} // end using sql command
} // end page load


</script>

