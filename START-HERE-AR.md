# بداية فريق FoxFlow

المستودع الرئيسي: https://github.com/Alshaya-A/SDA-project-FoxFlow

## المشروع

نبني منصة GitLab وRunner وDocker على Azure باستخدام Terraform، ومعها تطبيق Node.js تجريبي لإثبات البناء والاختبار والفحص الأمني والنشر والإشعار.

## حالة التجهيز — 10 سبتمبر 2026

- تم التحقق من وجود المستودع الخاص تحت حساب Alshaya-A. لا توجد Organization للفريق في الحساب الظاهر أثناء الفحص.
- تم التحقق من اشتراك Azure فعال باسم Azure subscription 1.
- توجد مجموعة rg-foxflow-demo في uaenorth، وبداخلها vm-foxflow-demo وشبكة وقرص بيانات وموارد مرتبطة.
- وجود VM لا يثبت جاهزية GitLab أو Runner. لم يتم التحقق من تشغيلهما.
- لم تُرسل دعوات أعضاء؛ الأسماء والحسابات وتوزيع الأدوار لم تصل بعد.
- روابط Discord وDrive ولوحة المهام لم تُجهز بعد. لا تعد هذه القائمة إعلانًا باكتمال المنصات.

## توزيع الأدوار

| الدور | المسؤولية | البرامج الإضافية | أول تسليم |
| --- | --- | --- | --- |
| العضو 1 — يحدد الاسم | Azure وTerraform | Azure CLI، Terraform | هيكل البنية وتوثيق الموارد الموجودة وخطة State |
| العضو 2 — يحدد الاسم | Docker وGitLab وRunner والنسخ | Docker مع Compose، Bash، ShellCheck | تعريف Compose وأمثلة إعدادات المنصة |
| العضو 3 — يحدد الاسم | التطبيق والاختبارات | Node.js 24 مع npm، Docker مع Compose | تطبيق يعمل محليًا مع /health واختبارات وDockerfile |
| العضو 4 — يحدد الاسم | CI/CD والتكامل والنشر | Docker مع Compose، Node.js 24، Bash، ShellCheck، curl، jq | هيكل Pipeline واتفاق أوامر التطبيق |

كل عضو يحتاج VS Code وGit وOpenSSH ومتصفح وحساب GitHub مستقل. على Windows استخدموا WSL2 وUbuntu لأوامر Linux. GitHub Desktop اختياري.

روابط التثبيت الرسمية:

- VS Code: https://code.visualstudio.com/download
- Git: https://git-scm.com/downloads
- Docker: https://docs.docker.com/get-started/get-docker/
- Node.js: https://nodejs.org/en/download
- Terraform: https://developer.hashicorp.com/terraform/install
- Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli
- WSL: https://learn.microsoft.com/windows/wsl/install
- ShellCheck: https://www.shellcheck.net/

Terraform في المرجع يتطلب >= 1.6، وAzureRM ~> 4.0. يتفق العضو الأول مع الفريق على إصدار Terraform موحد قبل التنفيذ ويرفع ملف lock للمزوّدات. لا تعتمدوا منطقة ملفات المثال تلقائيًا: البيئة الموجودة في uaenorth.

## فحص الجهاز

الجميع:

```sh
git --version
ssh -V
```

العضو 1:

```sh
az version
terraform version
```

الأعضاء 2 و3 و4:

```sh
docker --version
docker compose version
docker info
```

الأعضاء 3 و4:

```sh
node --version
npm --version
```

بعد قبول دعوة المستودع:

```sh
git clone https://github.com/Alshaya-A/SDA-project-FoxFlow.git
cd SDA-project-FoxFlow
git switch -c setup/my-first-task
```

اضبط اسمك وبريد commits في Git. سجّل الدخول بالطريقة التي يعرضها Git أو مدير الاعتماد، ولا تضع token داخل الرابط.

## طريقة العمل

1. اختر Issue مسندة إليك.
2. أنشئ فرعًا للمهمة.
3. اكتب ملفات جزئك ووثّق طريقة فحصها.
4. ارفع Pull Request واربطها بالمهمة.
5. يراجع زميل التغيير ثم يُدمج في main.

المراجعون: 1 و2 يراجعان بعضهما، و3 و4 يراجعان بعضهما. يشترك 2 و4 في مراجعة Runner والنشر.

GitHub هو مصدر الكود الرئيسي. مشروع sample-app على GitLab يستقبل محتويات مجلد sample-app عبر طريقة يوثقها العضو الرابع؛ المزامنة ليست تلقائية الآن.

## تنظيم الملفات المستهدف

```text
terraform/       # العضو 1
docker/          # العضو 2
sample-app/      # العضو 3؛ ملف .gitlab-ci.yml وdeploy/ للعضو 4
scripts/         # حسب الوظيفة: بنية أو منصة أو مزامنة
docs/            # كل عضو يوثق جزأه
```

لا ترفعوا .env أو terraform.tfvars الفعلي أو State أو خطط Terraform أو مفاتيح SSH الخاصة أو tokens. ارفعوا أمثلة خالية من الأسرار وملفات lock.

## اتفاق الربط الأولي

- Ubuntu 24.04 للسيرفر وفق الخطة؛ يلزم التحقق من النظام الموجود قبل اعتماده.
- ملفات التشغيل /opt/foxflow والبيانات /srv/foxflow.
- التطبيق داخل الحاوية على المنفذ 3000، وGET /health يعيد 200 وJSON.
- Runner tag: foxflow.
- المراحل: Build → Test → Security Scan → Deploy → Notify.
- الصور المنشورة مرتبطة بمعرف commit.
- ممنوع تنفيذ apply على الموارد الموجودة قبل تحديد Terraform State الذي يديرها ومراجعة plan.

## معلومات يرسلها كل عضو لليدر

الاسم، حساب GitHub، بريد الدعوة، نظام الجهاز، الدور، وحالة تثبيت الأدوات. من يحتاج السيرفر يرسل المفتاح العام بصيغة .pub فقط. لا ترسلوا كلمات المرور.

## نجاح اليوم الأول

- قبول الدعوة وسحب المستودع.
- نجاح فحص البرامج المطلوبة للدور.
- معرفة أول مهمة والمراجع.
- فتح أول Pull Request صغير.
