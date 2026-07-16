#include <QApplication>
// qt shared header
#include "QtShared/QtShared.h"

#include <ProObjects.h>

#include <ProFeatType.h>
#include <ProSolid.h>

#include "PopupTest.h"

static void foo()
{
    ProMdl mdl;
    ProMdlCurrentGet(&mdl);

    ProMdlType type;
    ProMdlTypeGet(mdl, &type);
    if (type == PRO_PART)
    {
    }
}

static std::vector<ProMdl> getAsmCompModel(ProMdl assem)
{
    ProMdlType mdlType;
    ProMdlTypeGet(assem, &mdlType);
    if (mdlType != PRO_ASSEMBLY)
        return {};

    std::vector<ProMdl> result;
    auto status = ProSolidFeatVisit(
        (ProSolid)assem,
        [](ProFeature *feature, ProError status, ProAppData data)
        {
            ProMdl compModel;
            status = ProAsmcompMdlGet(feature, &compModel);
            if (status == PRO_TK_NO_ERROR)
            {
                auto arr = (std::vector<ProMdl> *)data;
                arr->push_back(compModel);
            }
            return PRO_TK_NO_ERROR;
        },
        [](ProFeature *feature, ProAppData data)
        {
            ProFeattype featType;
            ProError status = ProFeatureTypeGet(feature, &featType);
            if (status == PRO_TK_NO_ERROR && featType == PRO_FEAT_COMPONENT)
                return PRO_TK_NO_ERROR; // 接受此特征
            return PRO_TK_CONTINUE;     // 跳过其他特征
        },
        &result);

    return result;
}

/**
 * 递归获取所有组件（包括子装配下的所有零件和子装配）
 * @param assem 装配体模型
 * @param allCompModels 输出：所有组件的列表
 */
void getAsmCompModel2(ProMdl assem, std::vector<ProMdl> &allCompModels)
{
    auto compModels = getAsmCompModel(assem);
    for (auto mdl : compModels)
    {
        ProMdlType mdlType;
        ProMdlTypeGet(mdl, &mdlType);
        if (mdlType == PRO_PART)
            allCompModels.push_back(mdl); // 零件直接加入
        else if (mdlType == PRO_ASSEMBLY)
        {
            allCompModels.push_back(mdl);         // 子装配加入
            getAsmCompModel2(mdl, allCompModels); // 递归处理子装配
        }
    }
}

// 程序入口
extern "C" int user_initialize(
    int argc,
    char *argv[],
    char *version,
    char *build,
    wchar_t errbuf[80])
{
    QApplication *app = EnsureQApplication();

    // 注册零件参数检查菜单
    RegisterPartInspection();

    return 0;
}

// 程序出口
extern "C" void user_terminate()
{
    ReleaseQApplication();
}
