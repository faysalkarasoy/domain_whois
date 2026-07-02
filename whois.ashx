<%@ WebHandler Language="VB" Class="WhoisHandler" %>
<%@ Assembly Name="System.Web.Extensions, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" %>

Imports System
Imports System.Collections
Imports System.IO
Imports System.Net.Sockets
Imports System.Web
Imports System.Web.Script.Serialization

Public Class WhoisHandler
    Implements IHttpHandler

    Public Sub ProcessRequest(ByVal context As HttpContext) Implements IHttpHandler.ProcessRequest
        context.Response.ContentType = "text/plain; charset=utf-8"

        Dim domain As String = Lcase(context.Request.QueryString("domain"))
        Dim result As String = Me.Whois(domain)

        context.Response.Write(result)
    End Sub

    Public ReadOnly Property IsReusable() As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property

    Public Function Whois(ByVal inputText As String) As String
        Dim expr As String = If(inputText, "").Trim()

        If expr.Length <= 3 Then
            Return "error:no domain"
        End If

        Dim jsonPath As String = HttpContext.Current.Server.MapPath("~/App_Data/tld.servers.json")
        Dim serializer As New JavaScriptSerializer()
        Dim whoisServers As Dictionary(Of String, Object) = serializer.Deserialize(Of Dictionary(Of String, Object))(File.ReadAllText(jsonPath))

        Dim dotIndex As Integer = expr.LastIndexOf("."c)
        If dotIndex < 0 Then
            Return "error:not valid TLD"
        End If
        Dim tld As String = expr.Substring(dotIndex)

        Dim whoisServerInfo As Dictionary(Of String, Object) = Me.GetWhoisServerInfo(whoisServers, tld)
        If whoisServerInfo Is Nothing Then
            Return "error:not valid TLD"
        End If

        Dim host As String = whoisServerInfo("host").ToString()

        Dim port As Integer = 43
        If whoisServerInfo.ContainsKey("port") AndAlso whoisServerInfo("port") IsNot Nothing Then
            Integer.TryParse(whoisServerInfo("port").ToString(), port)
        End If

        Dim queryFormat As String = "{0}"
        If whoisServerInfo.ContainsKey("query_format") AndAlso whoisServerInfo("query_format") IsNot Nothing Then
            queryFormat = whoisServerInfo("query_format").ToString()
        End If

        Dim query As String = String.Format(queryFormat, expr)

        Return Me.PerformWhoisQuery(host, port, query)
    End Function

    Private Function GetWhoisServerInfo(ByVal whoisServers As Dictionary(Of String, Object), ByVal tld As String) As Dictionary(Of String, Object)
        If Not whoisServers.ContainsKey("liste") Then
            Return Nothing
        End If

        Dim serverList As ArrayList = TryCast(whoisServers("liste"), ArrayList)
        If serverList Is Nothing Then
            Return Nothing
        End If

        For Each item As Object In serverList
            Dim serverInfo As Dictionary(Of String, Object) = TryCast(item, Dictionary(Of String, Object))
            If serverInfo IsNot Nothing AndAlso serverInfo.ContainsKey("zone") Then
                If String.Equals(serverInfo("zone").ToString(), tld, StringComparison.OrdinalIgnoreCase) Then
                    Return serverInfo
                End If
            End If
        Next

        Return Nothing
    End Function

    Private Function PerformWhoisQuery(ByVal host As String, ByVal port As Integer, ByVal query As String) As String
        Dim result As String

        Try
            Using tcpClient As New TcpClient(host, port)
                Using stream As NetworkStream = tcpClient.GetStream()
                    Using writer As New StreamWriter(stream)
                        Using reader As New StreamReader(stream)
                            writer.WriteLine(query)
                            writer.Flush()
                            result = reader.ReadToEnd()
                        End Using
                    End Using
                End Using
            End Using
        Catch ex As Exception
            result = "error:" & ex.Message
        End Try

        Return result
    End Function

End Class
