import hudson.model.User
import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.AuthorizationStrategy

Jenkins j = Jenkins.get()
String adminPassword = System.getenv("MV_E14_ADMIN_PASSWORD") ?: "runtime-secret-required"

HudsonPrivateSecurityRealm realm = new HudsonPrivateSecurityRealm(false)
if (realm.getUser("admin") == null) {
  realm.createAccount("admin", adminPassword)
}
j.setSecurityRealm(realm)

// Intentionally keep anonymous read access so CVE-2024-23897 CLI file-read
// remains reachable from the Chain B pivot. Do not expose remoting agents.
j.setAuthorizationStrategy(AuthorizationStrategy.UNSECURED)
j.setSlaveAgentPort(-1)
j.save()
